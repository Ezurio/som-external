// SPDX-License-Identifier: LicenseRef-Ezurio-Clause
// Copyright (C) 2026 Ezurio

#include <errno.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <hsm/hsm_api.h>

#define KEY_STORE_ID          UINT32_C(0x454c4500)
#define KEY_STORE_NONCE       UINT32_C(0x00001234)
#define PERSISTENT_MASTER_ID  UINT32_C(1)
#define EXPECTED_KE_SIZE      576u
#define EXPECTED_KE_NONE_SIZE 504u
#define EXPECTED_TLV_SIZE     141u
#define GCM_IV_SIZE           12u
#define GCM_TAG_SIZE          16u
/*
 * The kernel ELE driver gives each user 128 KiB of shared memory
 * (MAX_DATA_SIZE_PER_USER), which must hold the IV and tag (each padded to
 * 16 bytes) plus the input and output buffers. Larger requests can reset the
 * SoC instead of failing cleanly, so reject them before calling ELE.
 */
#define MAX_PLAINTEXT_SIZE    65520u

static uint8_t *read_file(const char *path, size_t *size)
{
    FILE *file = NULL;
    uint8_t *data = NULL;
    long length;

    file = fopen(path, "rb");
    if (!file) {
        fprintf(stderr, "fopen(%s): %s\n", path, strerror(errno));
        return NULL;
    }
    if (fseek(file, 0, SEEK_END) != 0 || (length = ftell(file)) < 0 ||
        fseek(file, 0, SEEK_SET) != 0) {
        fprintf(stderr, "size(%s): %s\n", path, strerror(errno));
        fclose(file);
        return NULL;
    }
    if ((unsigned long)length > SIZE_MAX || length == 0) {
        fprintf(stderr, "invalid size for %s: %ld\n", path, length);
        fclose(file);
        return NULL;
    }
    data = malloc((size_t)length);
    if (!data) {
        fprintf(stderr, "malloc(%ld): %s\n", length, strerror(errno));
        fclose(file);
        return NULL;
    }
    if (fread(data, 1, (size_t)length, file) != (size_t)length) {
        fprintf(stderr, "read(%s): %s\n", path,
                ferror(file) ? strerror(errno) : "short read");
        free(data);
        fclose(file);
        return NULL;
    }
    fclose(file);
    *size = (size_t)length;
    return data;
}

static int write_file(const char *path, const uint8_t *data, size_t size)
{
    FILE *file = fopen(path, "wb");

    if (!file) {
        fprintf(stderr, "fopen(%s): %s\n", path, strerror(errno));
        return -1;
    }
    if (fwrite(data, 1, size, file) != size) {
        fprintf(stderr, "write(%s): %s\n", path, strerror(errno));
        fclose(file);
        return -1;
    }
    if (fclose(file) != 0) {
        fprintf(stderr, "close(%s): %s\n", path, strerror(errno));
        return -1;
    }
    return 0;
}

static int report_hsm_error(const char *operation, hsm_err_t err)
{
    if (err == HSM_NO_ERROR) {
        printf("[PASS] %s\n", operation);
        return 0;
    }
    fprintf(stderr, "[FAIL] %s: HSM error 0x%x\n", operation, err);
    return -1;
}

/*
 * The artifacts are generated for the SRK-bound NXP KA key reported in OEM
 * Closed and OEM Locked. Refuse to touch the key store in any other lifecycle
 * so that no unusable persistent master is created.
 */
static int check_lifecycle(hsm_hdl_t session_hdl)
{
    op_get_info_args_t info_args = {0};
    const char *name = NULL;
    hsm_err_t err;

    err = hsm_get_info(session_hdl, &info_args);
    free(info_args.chip_unique_id);
    if (report_hsm_error("get ELE device info", err))
        return -1;

    switch (info_args.chip_life_cycle) {
    case SOC_LF_CLOSED:
        name = "OEM Closed";
        break;
    case SOC_LF_CLOSED_LOCKED:
        name = "OEM Locked";
        break;
    case SOC_LF_OPEN:
        fprintf(stderr, "[FAIL] device lifecycle: 0x%x (OEM Open); "
                "provisioning requires OEM Closed or OEM Locked\n",
                info_args.chip_life_cycle);
        return -1;
    default:
        fprintf(stderr, "[FAIL] device lifecycle: 0x%x (unknown); "
                "provisioning requires OEM Closed or OEM Locked\n",
                info_args.chip_life_cycle);
        return -1;
    }
    printf("[INFO] device lifecycle: 0x%x (%s)\n",
           info_args.chip_life_cycle, name);
    return 0;
}

static void usage(const char *program)
{
    fprintf(stderr,
            "Usage: %s [--reuse-only] KEY_EXCHANGE OEM_ECDH_PUBLIC "
            "KEY_IMPORT_TLV PAYLOAD OUTPUT\n",
            program);
}

int main(int argc, char **argv)
{
    uint8_t *signed_message = NULL;
    uint8_t *import_tlv = NULL;
    uint8_t *payload = NULL;
    uint8_t *plaintext = NULL;
    size_t signed_message_size = 0;
    size_t import_tlv_size = 0;
    size_t payload_size = 0;
    size_t plaintext_size;
    size_t public_key_size = 0;
    hsm_hdl_t session_hdl = 0;
    hsm_hdl_t key_store_hdl = 0;
    hsm_hdl_t key_mgmt_hdl = 0;
    open_session_args_t session_args = {0};
    open_svc_key_store_args_t key_store_args = {0};
    open_svc_key_management_args_t key_mgmt_args = {0};
    op_key_exchange_args_t exchange_args = {0};
    op_import_key_args_t import_args = {0};
    op_get_key_attr_args_t key_attr_args = {0};
    op_auth_enc_new_args_t decrypt_args = {0};
    hsm_err_t err;
    unsigned int load_attempt;
    int arg = 1;
    int reuse_only = 0;
    int master_key_exists = 0;
    int result = EXIT_FAILURE;

    if (argc > 1 && strcmp(argv[1], "--reuse-only") == 0) {
        reuse_only = 1;
        arg++;
    }
    if (argc - arg != 5) {
        usage(argv[0]);
        return EXIT_FAILURE;
    }

    signed_message = read_file(argv[arg], &signed_message_size);
    import_tlv = read_file(argv[arg + 2], &import_tlv_size);
    payload = read_file(argv[arg + 3], &payload_size);
    if (!signed_message || !import_tlv || !payload)
        goto cleanup;
    if (signed_message_size != EXPECTED_KE_SIZE &&
        signed_message_size != EXPECTED_KE_NONE_SIZE) {
        fprintf(stderr, "[FAIL] signed message size: got %zu, expected %u or %u\n",
                signed_message_size, EXPECTED_KE_SIZE, EXPECTED_KE_NONE_SIZE);
        goto cleanup;
    }
    if (import_tlv_size != EXPECTED_TLV_SIZE) {
        fprintf(stderr, "[FAIL] import TLV size: got %zu, expected %u\n",
                import_tlv_size, EXPECTED_TLV_SIZE);
        goto cleanup;
    }
    if (payload_size <= GCM_IV_SIZE + GCM_TAG_SIZE ||
        payload_size > GCM_IV_SIZE + MAX_PLAINTEXT_SIZE + GCM_TAG_SIZE) {
        fprintf(stderr, "[FAIL] invalid encrypted payload size: %zu (plaintext limit %u)\n",
                payload_size, MAX_PLAINTEXT_SIZE);
        goto cleanup;
    }
    plaintext_size = payload_size - GCM_IV_SIZE - GCM_TAG_SIZE;
    plaintext = calloc(1, plaintext_size);
    if (!plaintext) {
        fprintf(stderr, "calloc(%zu): %s\n", plaintext_size, strerror(errno));
        goto cleanup;
    }

    session_args.mu_type = HSM1;
    err = hsm_open_session(&session_args, &session_hdl);
    if (report_hsm_error("open HSM session", err))
        goto cleanup;

    if (check_lifecycle(session_hdl))
        goto cleanup;

    key_store_args.key_store_identifier = KEY_STORE_ID;
    key_store_args.authentication_nonce = KEY_STORE_NONCE;
    key_store_args.flags = HSM_SVC_KEY_STORE_FLAGS_LOAD;
    for (load_attempt = 0; load_attempt < 5; load_attempt++) {
        err = hsm_open_key_store_service(session_hdl, &key_store_args,
                                         &key_store_hdl);
        if (err != HSM_UNKNOWN_ID && err != HSM_NOT_READY_RATING)
            break;
        if (load_attempt < 4) {
            printf("[INFO] key store is not available yet; retrying load\n");
            sleep(1);
        }
    }
    if ((err == HSM_UNKNOWN_KEY_STORE || err == HSM_UNKNOWN_ID) &&
        !reuse_only) {
        key_store_args.flags = HSM_SVC_KEY_STORE_FLAGS_CREATE |
                               HSM_SVC_KEY_STORE_FLAGS_STRICT_OPERATION;
        err = hsm_open_key_store_service(session_hdl, &key_store_args,
                                         &key_store_hdl);
    }
    if (report_hsm_error("open key store 0x454c4500", err))
        goto cleanup;

    err = hsm_open_key_management_service(key_store_hdl, &key_mgmt_args,
                                          &key_mgmt_hdl);
    if (report_hsm_error("open key-management service", err))
        goto cleanup;

    import_args.input_lsb_addr = import_tlv;
    import_args.input_size = (uint32_t)import_tlv_size;
    import_args.flags = HSM_OP_IMPORT_KEY_INPUT_ELE_TLV |
                        HSM_OP_IMPORT_KEY_FLAGS_AUTOMATIC_GROUP;

    if (reuse_only) {
        master_key_exists = 1;
        printf("[INFO] reuse-only mode: strict key creation is disabled\n");
        key_attr_args.key_identifier = PERSISTENT_MASTER_ID;
        err = hsm_get_key_attr(key_mgmt_hdl, &key_attr_args);
        if (report_hsm_error("get attributes for persistent key ID 1", err))
            goto cleanup;
        printf("[INFO] key ID 1 attributes: type=0x%x size=%u lifetime=0x%x "
               "usage=0x%x algorithm=0x%x lifecycle=0x%x\n",
               key_attr_args.key_type, key_attr_args.bit_key_sz,
               key_attr_args.key_lifetime, key_attr_args.key_usage,
               key_attr_args.permitted_algo, key_attr_args.lifecycle);
        goto import_key;
    }

    err = hsm_import_key(key_mgmt_hdl, &import_args);
    if (err == HSM_NO_ERROR) {
        master_key_exists = 1;
        printf("[PASS] existing persistent master authenticated by ELE TLV import\n");
        goto imported_key;
    }
    if (err != HSM_CANNOT_RETRIEVE_KEY_GROUP && err != HSM_UNKNOWN_ID) {
        report_hsm_error("probe existing persistent master with ELE TLV import", err);
        goto cleanup;
    }
    printf("[INFO] persistent master is absent; creating it with one strict operation\n");

    exchange_args.in_content = signed_message;
    exchange_args.in_content_sz = (uint32_t)signed_message_size;
    exchange_args.in_pub_buffer = read_file(argv[arg + 1], &public_key_size);
    if (!exchange_args.in_pub_buffer || public_key_size != 64u) {
        fprintf(stderr, "[FAIL] OEM ECDH public key must be 64-byte X||Y\n");
        goto cleanup;
    }
    exchange_args.in_pub_buffer_sz = (uint32_t)public_key_size;
    exchange_args.flags = HSM_OP_KEY_EXCHANGE_FLAGS_INPUT_SIGNED_CONTENT |
                          HSM_OP_KEY_EXCHANGE_FLAGS_STRICT_OPERATION;
    err = hsm_key_exchange(key_mgmt_hdl, &exchange_args);
    if (err == HSM_ID_CONFLICT) {
        master_key_exists = 1;
        printf("[PASS] persistent OEM_IMPORT_MK_SK ID 1 already exists\n");
    } else if (report_hsm_error(
                   "strict signed key exchange (create persistent OEM_IMPORT_MK_SK ID 1)",
                   err)) {
        goto cleanup;
    }
    if (!master_key_exists) {
        if (exchange_args.out_derived_key_id != PERSISTENT_MASTER_ID) {
            fprintf(stderr, "[FAIL] ELE returned derived key ID %u, expected %u\n",
                    exchange_args.out_derived_key_id, PERSISTENT_MASTER_ID);
            goto cleanup;
        }
        printf("[INFO] persistent derived key ID: %u\n",
               exchange_args.out_derived_key_id);
    }
    free(exchange_args.in_pub_buffer);
    exchange_args.in_pub_buffer = NULL;

import_key:
    err = hsm_import_key(key_mgmt_hdl, &import_args);
    if (report_hsm_error(master_key_exists ?
                         "ELE TLV import using existing persistent master" :
                         "ELE TLV import using newly persisted master", err))
        goto cleanup;
imported_key:
    printf("[INFO] imported volatile key ID: %u\n", import_args.key_identifier);
    if (import_args.key_identifier == 0) {
        fprintf(stderr, "[FAIL] ELE returned an invalid imported key ID\n");
        goto cleanup;
    }

    decrypt_args.key_id = import_args.key_identifier;
    decrypt_args.iv_in = payload;
    decrypt_args.iv_size = GCM_IV_SIZE;
    decrypt_args.ae_algo = HSM_AEAD_ALGO_GCM;
    decrypt_args.flags = HSM_AUTH_ENC_FLAGS_DECRYPT |
                         HSM_AUTH_ENC_FLAGS_ONE_SHOT;
    decrypt_args.input = payload + GCM_IV_SIZE;
    decrypt_args.input_size = (uint32_t)plaintext_size;
    decrypt_args.tag = payload + payload_size - GCM_TAG_SIZE;
    decrypt_args.tag_size = GCM_TAG_SIZE;
    decrypt_args.output = plaintext;
    decrypt_args.output_size = (uint32_t)plaintext_size;
    err = hsm_do_auth_enc_new(key_store_hdl, &decrypt_args);
    if (err == HSM_OUT_TOO_SMALL)
        fprintf(stderr, "[INFO] ELE expected output size: %u\n",
                decrypt_args.exp_output_size);
    if (report_hsm_error("AES-256-GCM authenticated decrypt", err))
        goto cleanup;
    if (decrypt_args.verify_status != HSM_AEAD_VERIFICATION_STATUS_SUCCESS) {
        fprintf(stderr, "[FAIL] AES-GCM verification status: 0x%x\n",
                decrypt_args.verify_status);
        goto cleanup;
    }

    if (write_file(argv[arg + 4], plaintext, plaintext_size) != 0)
        goto cleanup;
    printf("[PASS] wrote %zu authenticated plaintext bytes to %s\n",
           plaintext_size, argv[arg + 4]);
    result = EXIT_SUCCESS;

cleanup:
    free(exchange_args.in_pub_buffer);
    if (key_mgmt_hdl)
        report_hsm_error("close key-management service",
                         hsm_close_key_management_service(key_mgmt_hdl));
    if (key_store_hdl)
        report_hsm_error("close key store",
                         hsm_close_key_store_service(key_store_hdl));
    if (session_hdl)
        report_hsm_error("close HSM session", hsm_close_session(session_hdl));
    free(plaintext);
    free(payload);
    free(import_tlv);
    free(signed_message);
    return result;
}
