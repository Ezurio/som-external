/*
 * SPDX-License-Identifier: LicenseRef-Ezurio-Clause
 * Copyright (C) 2025 Ezurio LLC.
 */

#include "summit_prov.h"

static char *input_file = "";
module_param(input_file, charp, 0);

static char *output_file = "";
module_param(output_file, charp, 0);

static bool use_ti_sci = true;
module_param(use_ti_sci, bool, 0);

static int decrypt_aes_cbc(u8 *data, u8 *key, u8 *iv_data, unsigned int len)
{
    struct crypto_skcipher *tfm = NULL;
    struct skcipher_request *req = NULL;
    struct scatterlist sg;
    DECLARE_CRYPTO_WAIT(wait);
    int err;

    tfm = crypto_alloc_skcipher("cbc(aes)", 0, 0);
    if (IS_ERR(tfm))
    {
        printk(KERN_ERR "Error allocating cbc(aes) handle: %px\n", PTR_ERR(tfm));
        return PTR_ERR(tfm);
    }

    err = crypto_skcipher_setkey(tfm, key, AES_KEY_SIZE);
    if (err)
    {
        printk(KERN_ERR "Error setting AES key: %d\n", err);
        goto out;
    }

    req = skcipher_request_alloc(tfm, GFP_KERNEL);
    if (!req)
    {
        printk(KERN_ERR "Error allocating skcipher request\n");
        err = -ENOMEM;
        goto out;
    }

    sg_init_one(&sg, data, len);
    skcipher_request_set_callback(req, CRYPTO_TFM_REQ_MAY_SLEEP | CRYPTO_TFM_REQ_MAY_BACKLOG,
                                  crypto_req_done, &wait);
    skcipher_request_set_crypt(req, &sg, &sg, len, iv_data);
    err = crypto_wait_req(crypto_skcipher_decrypt(req), &wait);
    if (err)
    {
        printk(KERN_ERR "Error during AES decryption: %d\n", err);
        goto out;
    }

out:
    crypto_free_skcipher(tfm);
    skcipher_request_free(req);
    return err;
}

struct k3conf_soc_info soc_info;

static int seq = 0;

struct k3_sec_proxy_base k3_generic_sec_proxy_base = {
    .src_target_data = 0x32c00000,
    .cfg_scfg = 0x32800000,
    .cfg_rt = 0x32400000,
};

struct k3_sec_proxy_base k3_lite_sec_proxy_base = {
    .src_target_data = 0x4d000000,
    .cfg_scfg = 0x4a400000,
    .cfg_rt = 0x4a600000,
};

struct k3_sec_proxy_thread
{
    u32 id;
    uintptr_t data;
    uintptr_t scfg;
    uintptr_t rt;
} spts[SEC_PROXY_MAX_THREADS];

struct ti_sci_sec_proxy_info am62x_main_sp_info[] = {
    {69, "read", 34, "DM", "nonsec_low_priority_rx"},
    {68, "write", 11, "DM", "nonsec_MAIN_0_R5_1_response_tx"},
    {67, "write", 2, "DM", "nonsec_MAIN_0_R5_3_response_tx"},
    {66, "write", 6, "DM", "nonsec_A53_2_response_tx"},
    {65, "write", 6, "DM", "nonsec_A53_3_response_tx"},
    {64, "write", 6, "DM", "nonsec_M4_0_response_tx"},
    {63, "write", 2, "DM", "nonsec_GPU_response_tx"},
    {62, "write", 6, "DM", "nonsec_A53_4_response_tx"},
    {61, "write", 4, "DM", "nonsec_TIFS2DM_response_tx"},
    {0, "read", 11, "MAIN_0_R5_0", "response"},
    {1, "write", 10, "MAIN_0_R5_0", "low_priority"},
    {2, "read", 11, "MAIN_0_R5_1", "response"},
    {3, "write", 10, "MAIN_0_R5_1", "low_priority"},
    {4, "read", 2, "MAIN_0_R5_2", "response"},
    {5, "write", 1, "MAIN_0_R5_2", "low_priority"},
    {6, "read", 2, "MAIN_0_R5_3", "response"},
    {7, "write", 1, "MAIN_0_R5_3", "low_priority"},
    {8, "read", 11, "A53_0", "response"},
    {9, "write", 10, "A53_0", "low_priority"},
    {10, "read", 11, "A53_1", "response"},
    {11, "write", 10, "A53_1", "low_priority"},
    {12, "read", 6, "A53_2", "response"},
    {13, "write", 5, "A53_2", "low_priority"},
    {14, "read", 6, "A53_3", "response"},
    {15, "write", 5, "A53_3", "low_priority"},
    {16, "read", 6, "M4_0", "response"},
    {17, "write", 5, "M4_0", "low_priority"},
    {18, "read", 2, "GPU", "response"},
    {19, "write", 1, "GPU", "low_priority"},
    {20, "read", 6, "A53_4", "response"},
    {21, "write", 5, "A53_4", "low_priority"},
    {22, "read", 4, "DM2TIFS", "response"},
    {23, "write", 4, "DM2TIFS", "low_priority"},
    {24, "read", 4, "TIFS2DM", "response"},
    {25, "write", 2, "TIFS2DM", "low_priority"},
};

struct ti_sci_sec_proxy_info am62x_mcu_sp_info[] = {
    {15, "read", 8, "TIFS_HSM", "sec_low_priority_rx"},
    {14, "write", 8, "TIFS_HSM", "sec_HSM_response_tx"},
    {0, "read", 8, "HSM", "response"},
    {1, "write", 8, "HSM", "low_priority"},
};

struct ti_sci_host_info am62x_host_info[] = {
    {0, "TIFS", "Secure", "Device Management and Security Control"},
    {10, "A53_0", "Secure", "Cortex a53 context 0 on Main island"},
    {11, "A53_1", "Secure", "Cortex A53 context 1 on Main island"},
    {12, "A53_2", "Non Secure", "Cortex A53 context 2 on Main island"},
    {13, "A53_3", "Non Secure", "Cortex A53 context 3 on Main island"},
    {14, "A53_4", "Non Secure", "Cortex A53 context 1 on Main island"},
    {30, "M4_0", "Non Secure", "M4"},
    {31, "GPU", "Non Secure", "GPU context 0 on Main island"},
    {35, "MAIN_0_R5_0", "Secure", "Cortex R5_0 context 0 on Main island(BOOT)"},
    {36, "MAIN_0_R5_1", "Non Secure", "Cortex R5_0 context 1 on Main island"},
    {37, "MAIN_0_R5_2", "Secure", "Cortex R5_0 context 2 on Main island"},
    {38, "MAIN_0_R5_3", "Non Secure", "Cortex R5_0 context 3 on Main island"},
    {250, "DM2TIFS", "Secure", "DM to TIFS communication"},
    {251, "TIFS2DM", "Non Secure", "TIFS to DM communication"},
    {253, "HSM", "Secure", "HSM Controller"},
    {254, "DM", "Non Secure", "Device Management"},
};

// Dummy dev to enable DMA allocations
static struct device dev = {
    .init_name = "mydmadev",
    .coherent_dma_mask = ~0,            // dma_alloc_coherent(): allow any address
    .dma_mask = &dev.coherent_dma_mask, // other APIs: use the same mask as coherent
};

enum k3_device_type get_device_type(void)
{
    void *virt_addr;
    enum k3_device_type dev_type;

    virt_addr = ioremap(K3_SEC_MGR_SYS_STATUS, sizeof(u32));
    if (!virt_addr)
    {
        printk(KERN_ERR "%s: Failed to ioremap sys status addr 0x%lx\n",
               __func__, K3_SEC_MGR_SYS_STATUS);
        return K3_DEVICE_TYPE_BAD;
    }

    u32 sys_status = readl(virt_addr);

    u32 sys_dev_type = (sys_status & SYS_STATUS_DEV_TYPE_MASK) >>
                       SYS_STATUS_DEV_TYPE_SHIFT;

    u32 sys_sub_type = (sys_status & SYS_STATUS_SUB_TYPE_MASK) >>
                       SYS_STATUS_SUB_TYPE_SHIFT;

    switch (sys_dev_type)
    {
    case SYS_STATUS_DEV_TYPE_GP:
        dev_type = K3_DEVICE_TYPE_GP;
        break;
    case SYS_STATUS_DEV_TYPE_TEST:
        dev_type = K3_DEVICE_TYPE_TEST;
        break;
    case SYS_STATUS_DEV_TYPE_EMU:
        dev_type = K3_DEVICE_TYPE_EMU;
        break;
    case SYS_STATUS_DEV_TYPE_HS:
        if (sys_sub_type == SYS_STATUS_SUB_TYPE_VAL_FS)
            dev_type = K3_DEVICE_TYPE_HS_FS;
        else
            dev_type = K3_DEVICE_TYPE_HS_SE;
        break;
    default:
        dev_type = K3_DEVICE_TYPE_BAD;
        break;
    }

    iounmap(virt_addr);

    return dev_type;
}

static int k3_sec_proxy_verify_thread(u32 dir)
{
    struct k3_sec_proxy_thread *spt = &spts[dir];
    void *virt_addr;

    /* Check for any errors already available */
    virt_addr = ioremap(spt->rt + RT_THREAD_STATUS, sizeof(u32));
    if (!virt_addr)
    {
        printk(KERN_ERR "%s: Failed to ioremap rt addr 0x%px\n",
               __func__, spt->rt + RT_THREAD_STATUS);
        return -1;
    }
    if (readl(virt_addr) &
        RT_THREAD_STATUS_ERROR_MASK)
    {
        iounmap(virt_addr);
        printk(KERN_ERR "%s: Thread %d is corrupted, cannot send data.\n",
               __func__, spt->id);
        return -1;
    }
    iounmap(virt_addr);

    /* Make sure thread is configured for right direction */
    virt_addr = ioremap(spt->scfg + SCFG_THREAD_CTRL, sizeof(u32));
    if (!virt_addr)
    {
        printk(KERN_ERR "%s: Failed to ioremap scfg addr 0x%px\n",
               __func__, spt->scfg + SCFG_THREAD_CTRL);
        return -1;
    }
    if (((readl(virt_addr) & SCFG_THREAD_CTRL_DIR_MASK) >> SCFG_THREAD_CTRL_DIR_SHIFT) != dir)
    {
        iounmap(virt_addr);
        if (dir)
        {
            printk(KERN_ERR "%s: Trying to receive data on tx Thread %d\n",
                   __func__, spt->id);
        }
        else
        {
            printk(KERN_ERR "%s: Trying to send data on rx Thread %d\n",
                   __func__, spt->id);
        }
        return -1;
    }
    iounmap(virt_addr);

    /* Check the message queue before sending/receiving data */
    virt_addr = ioremap(spt->rt + RT_THREAD_STATUS, sizeof(u32));
    if (!virt_addr)
    {
        printk(KERN_ERR "%s: Failed to ioremap rt addr 0x%px\n",
               __func__, spt->rt + RT_THREAD_STATUS);
        return -1;
    }
    if (!(readl(virt_addr) & RT_THREAD_STATUS_CUR_CNT_MASK))
    {
        iounmap(virt_addr);
        return -2;
    }

    iounmap(virt_addr);
    return 0;
}

int k3_sec_proxy_send(struct k3_sec_proxy_msg *msg)
{
    struct k3_sec_proxy_thread *spt = &spts[SEC_PROXY_TX_THREAD];
    int num_words, trail_bytes, ret;
    u32 *word_data;
    uintptr_t data_reg;
    void *virt_addr;

    ret = k3_sec_proxy_verify_thread(SEC_PROXY_TX_THREAD);
    if (ret)
    {
        printk(KERN_ERR "%s: Thread%d verification failed. ret = %d\n",
               __func__, spt->id, ret);
        return ret;
    }

    /* Check the message size. */
    if (msg->len > SEC_PROXY_MAX_MSG_SIZE)
    {
        printk(KERN_ERR "%s: Thread %u message length %zu > max msg size %d\n",
               __func__, spt->id, msg->len, SEC_PROXY_MAX_MSG_SIZE);
        return -1;
    }

    /* Send the message */
    data_reg = spt->data + SEC_PROXY_DATA_START_OFFS;
    word_data = (u32 *)msg->buf;
    for (num_words = msg->len / sizeof(u32);
         num_words;
         num_words--, data_reg += sizeof(u32), word_data++)
    {
        virt_addr = ioremap(data_reg, sizeof(u32));
        if (!virt_addr)
        {
            printk(KERN_ERR "%s: Failed to ioremap data addr 0x%px\n",
                   __func__, data_reg);
            return -1;
        }
        writel(*word_data, virt_addr);
        iounmap(virt_addr);
    }

    trail_bytes = msg->len % sizeof(u32);
    if (trail_bytes)
    {
        u32 data_trail = *word_data;

        /* Ensure all unused data is 0 */
        data_trail &= 0xFFFFFFFF >> (8 * (sizeof(u32) - trail_bytes));
        virt_addr = ioremap(data_reg, sizeof(u32));
        if (!virt_addr)
        {
            printk(KERN_ERR "%s: Failed to ioremap data addr 0x%px\n",
                   __func__, data_reg);
            return -1;
        }
        writel(data_trail, virt_addr);
        iounmap(virt_addr);
        data_reg++;
    }

    /*
     * 'data_reg' indicates next register to write. If we did not already
     * write on tx complete reg(last reg), we must do so for transmit
     */
    if (data_reg <= (spt->data + SEC_PROXY_DATA_END_OFFS))
    {
        virt_addr = ioremap(spt->data + SEC_PROXY_DATA_END_OFFS, sizeof(u32));
        if (!virt_addr)
        {
            printk(KERN_ERR "%s: Failed to ioremap data addr 0x%px\n",
                   __func__, spt->data + SEC_PROXY_DATA_END_OFFS);
            return -1;
        }
        writel(0, virt_addr);
        iounmap(virt_addr);
    }

    return 0;
}

int k3_sec_proxy_recv(struct k3_sec_proxy_msg *msg)
{
    struct k3_sec_proxy_thread *spt = &spts[SEC_PROXY_RX_THREAD];
    int num_words, ret = -1, retry = SEC_PROXY_RECV_MAX_RETRIES;
    u32 *word_data;
    resource_size_t data_reg;
    void *virt_addr;

    while (retry-- && ret)
    {
        ret = k3_sec_proxy_verify_thread(SEC_PROXY_RX_THREAD);
        if ((ret && ret != -2) || !retry)
        {
            printk(KERN_ERR "%s: Thread%d verification failed. ret = %d\n",
                   __func__, spt->id, ret);
            return ret;
        }
    }

    data_reg = spt->data + SEC_PROXY_DATA_START_OFFS;
    word_data = (u32 *)(uintptr_t)msg->buf;
    for (num_words = SEC_PROXY_MAX_MSG_SIZE / sizeof(u32);
         num_words;
         num_words--, data_reg += sizeof(u32), word_data++)
    {
        virt_addr = ioremap(data_reg, sizeof(u32));
        if (!virt_addr)
        {
            printk(KERN_ERR "%s: Failed to ioremap data addr 0x%px\n",
                   __func__, (void *)data_reg);
            return -1;
        }
        *word_data = readl(virt_addr);
        iounmap(virt_addr);
    }

    return 0;
}

static int get_thread_id(char *host_name, char *function)
{
    struct ti_sci_info *sci_info = &soc_info.sci_info;
    u32 i;

    for (i = 0; i < sci_info->num_sp_threads[MAIN_SEC_PROXY]; i++)
        if (!strcmp(host_name,
                    sci_info->sp_info[MAIN_SEC_PROXY][i].host) &&
            !strcmp(function,
                    sci_info->sp_info[MAIN_SEC_PROXY][i].host_function))
            return sci_info->sp_info[MAIN_SEC_PROXY][i].sp_id;

    return -1;
}

static char *get_host_name(u32 host_id)
{
    struct ti_sci_info *sci_info = &soc_info.sci_info;
    u32 i;

    for (i = 0; i < sci_info->num_hosts; i++)
        if (host_id == sci_info->host_info[i].host_id)
            return sci_info->host_info[i].host_name;

    return NULL;
}

int k3_sec_proxy_init(void)
{
    struct k3_sec_proxy_base *spb = soc_info.sec_proxy;
    int rx_thread, tx_thread;
    char *host_name;

    host_name = get_host_name(soc_info.host_id);
    if (!host_name)
    {
        printk(KERN_ERR "Invalid host id %d, using default host_id %d\n",
               soc_info.host_id, DEFAULT_HOST_ID);
        soc_info.host_id = DEFAULT_HOST_ID;
        host_name = get_host_name(soc_info.host_id);
    }

    rx_thread = get_thread_id(host_name, "response");
    if (rx_thread < 0)
    {
        printk(KERN_ERR "Invalid host id %d, using default host_id %d\n",
               soc_info.host_id, DEFAULT_HOST_ID);
        soc_info.host_id = DEFAULT_HOST_ID;
        host_name = get_host_name(soc_info.host_id);
        rx_thread = get_thread_id(host_name, "response");
    }
    tx_thread = get_thread_id(host_name, "low_priority");

    spts[SEC_PROXY_TX_THREAD].id = tx_thread;
    spts[SEC_PROXY_TX_THREAD].data = SEC_PROXY_THREAD(spb->src_target_data, tx_thread);
    spts[SEC_PROXY_TX_THREAD].scfg = SEC_PROXY_THREAD(spb->cfg_scfg, tx_thread);
    spts[SEC_PROXY_TX_THREAD].rt = SEC_PROXY_THREAD(spb->cfg_rt, tx_thread);

    spts[SEC_PROXY_RX_THREAD].id = rx_thread;
    spts[SEC_PROXY_RX_THREAD].data = SEC_PROXY_THREAD(spb->src_target_data, rx_thread);
    spts[SEC_PROXY_RX_THREAD].scfg = SEC_PROXY_THREAD(spb->cfg_scfg, rx_thread);
    spts[SEC_PROXY_RX_THREAD].rt = SEC_PROXY_THREAD(spb->cfg_rt, rx_thread);

    return 0;
}

void ti_sci_setup_header(struct ti_sci_msg_hdr *hdr, u16 type,
                         u32 flags)
{
    hdr->type = type;
    hdr->host = soc_info.host_id;
    hdr->seq = seq++;
    hdr->flags = TI_SCI_FLAG_REQ_ACK_ON_PROCESSED | flags;
}

int ti_sci_xfer_msg(struct k3_sec_proxy_msg *msg)
{
    int ret;

    if (!msg->len || !msg->buf)
    {
        printk(KERN_ERR "Invalid message for transfer\n");
        return -1;
    }

    ret = k3_sec_proxy_send(msg);
    if (ret)
    {
        printk(KERN_ERR "Failed to send message to secure proxy: %d\n", ret);
        return ret;
    }

    memset(msg->buf, 0, msg->len);
    ret = k3_sec_proxy_recv(msg);
    if (ret)
    {
        printk(KERN_ERR "Failed to receive message from secure proxy: %d\n", ret);
        return ret;
    }

    if (!ti_sci_is_response_ack(msg->buf))
    {
        printk(KERN_ERR "Received NACK from secure proxy\n");
        return -1;
    }

    return 0;
}

int ti_sci_cmd_proc_auth_boot_image_file(void **p_image, size_t *p_size)
{
    struct ti_sci_msg_req_proc_auth_boot_image *req;
    struct ti_sci_msg_resp_proc_auth_boot_image *resp;
    u8 buf[SEC_PROXY_MAX_MSG_SIZE];
    struct k3_sec_proxy_msg msg;
    int ret = 0;
    u64 image_addr;
    u32 image_size;

    image_size = *p_size;
    image_addr = dma_map_single(&dev, *p_image, *p_size, DMA_BIDIRECTIONAL);
    if (dma_mapping_error(&dev, image_addr))
    {
        printk(KERN_ERR "Failed to map image buffer for DMA\n");
        return -ENOMEM;
    }

    memset(buf, 0, sizeof(buf));
    ti_sci_setup_header((struct ti_sci_msg_hdr *)buf,
                        TI_SCI_MSG_PROC_AUTH_BOOT_IMAGE, 0);
    req = (struct ti_sci_msg_req_proc_auth_boot_image *)buf;

    req->cert_addr_low = image_addr & TISCI_ADDR_LOW_MASK;
    req->cert_addr_high = (image_addr & TISCI_ADDR_HIGH_MASK) >>
                          TISCI_ADDR_HIGH_SHIFT;

    msg.len = sizeof(*req);
    msg.buf = buf;
    ret = ti_sci_xfer_msg(&msg);
    if (ret)
    {
        printk(KERN_ERR "Failed to process/authenticate boot image: %d\n", ret);
        dma_unmap_single(&dev, image_addr, image_size, DMA_BIDIRECTIONAL);
        return ret;
    }

    resp = (struct ti_sci_msg_resp_proc_auth_boot_image *)buf;

    *p_image = (void *)((resp->image_addr_low & TISCI_ADDR_LOW_MASK) |
                        (((u64)resp->image_addr_high << TISCI_ADDR_HIGH_SHIFT) & TISCI_ADDR_HIGH_MASK));
    *p_size = resp->image_size;

    dma_unmap_single(&dev, image_addr, image_size, DMA_BIDIRECTIONAL);

    return 0;
}

static int decrypt_image(enum k3_device_type dev_type)
{
    int ret = 0;
    struct file *in_file = NULL;
    struct file *out_file = NULL;
    void *in_buffer = NULL;
    ssize_t bytes_read;
    unsigned long addr;
    ssize_t bytes_written;
    struct key *key;
    struct key *iv;

    if (input_file[0] == '\0' || output_file[0] == '\0')
    {
        printk(KERN_ERR "Input and output file paths must be provided\n");
        return -EINVAL;
    }

    in_file = filp_open(input_file, O_RDONLY, 0);
    if (IS_ERR(in_file))
    {
        printk(KERN_ERR "Failed to open input file: %s\n", input_file);
        return PTR_ERR(in_file);
    }

    loff_t file_size = i_size_read(file_inode(in_file));
    if (file_size <= 0 || file_size > MAX_INPUT_FILE_SIZE)
    {
        printk(KERN_ERR "Invalid input file size: %px\n", file_size);
        filp_close(in_file, NULL);
        return -EINVAL;
    }

    in_buffer = kmalloc(file_size, GFP_KERNEL);
    if (!in_buffer)
    {
        printk(KERN_ERR "Failed to allocate input buffer\n");
        filp_close(in_file, NULL);
        return -ENOMEM;
    }

    bytes_read = kernel_read(in_file, in_buffer, file_size, 0);
    filp_close(in_file, NULL);
    if (bytes_read < 0)
    {
        printk(KERN_ERR "Failed to read input file: %s\n", input_file);
        kfree(in_buffer);
        return bytes_read;
    }

    if (use_ti_sci == true)
    {
        if (dev_type == K3_DEVICE_TYPE_HS_SE)
        {
            addr = (unsigned long)in_buffer;

            ret = ti_sci_cmd_proc_auth_boot_image_file((void **)&addr, (size_t *)&bytes_read);

            if (ret)
            {
                printk(KERN_ERR "Failed to decrypt/authenticate image: %d\n", ret);
                kfree(in_buffer);
                return ret;
            }
        }
        else
        {
            printk(KERN_WARNING "Device type %d not supported for decryption/authentication, "
                                "file will just be copied without modification\n",
                   dev_type);
        }
    }
    else
    {
        // Decrypt using key/IV from kernel keyring
        key = request_key(&key_type_user, SUMMIT_PROV_DECRYPT_KEY_DESC, NULL);
        if (IS_ERR(key))
        {
            printk(KERN_ERR "Failed to request decryption key from keyring\n");
            kfree(in_buffer);
            return PTR_ERR(key);
        }

        iv = request_key(&key_type_user, SUMMIT_PROV_DECRYPT_IV_DESC, NULL);
        if (IS_ERR(iv))
        {
            printk(KERN_ERR "Failed to request decryption IV from keyring\n");
            key_put(key);
            kfree(in_buffer);
            return PTR_ERR(iv);
        }
        struct user_key_payload *key_payload = (struct user_key_payload *)key->payload.data[0];
        struct user_key_payload *iv_payload = (struct user_key_payload *)iv->payload.data[0];

        // Pad bytes_read to AES block size
        if (bytes_read % AES_BLOCK_SIZE != 0)
        {
            size_t padded_size = ((bytes_read / AES_BLOCK_SIZE) + 1) * AES_BLOCK_SIZE;
            u8 *padded_buffer = kmalloc(padded_size, GFP_KERNEL);
            if (!padded_buffer)
            {
                printk(KERN_ERR "Failed to allocate padded buffer\n");
                key_put(key);
                key_put(iv);
                kfree(in_buffer);
                return -ENOMEM;
            }
            memcpy(padded_buffer, in_buffer, bytes_read);
            memset(padded_buffer + bytes_read, 0, padded_size - bytes_read);
            kfree(in_buffer);
            in_buffer = padded_buffer;
            bytes_read = padded_size;
        }

        ret = decrypt_aes_cbc(in_buffer,
                              key_payload->data,
                              iv_payload->data,
                              bytes_read);
        if (ret)
        {
            printk(KERN_ERR "AES decryption failed: %d\n", ret);
            key_put(key);
            key_put(iv);
            kfree(in_buffer);
            return ret;
        }

        // Clean up keys
        key_put(key);
        key_put(iv);
    }

    out_file = filp_open(output_file, O_WRONLY | O_CREAT | O_TRUNC, 0600);
    if (IS_ERR(out_file))
    {
        printk(KERN_ERR "Failed to open output file: %s\n", output_file);
        kfree(in_buffer);
        return PTR_ERR(out_file);
    }

    bytes_written = kernel_write(out_file, in_buffer, bytes_read, 0);
    filp_close(out_file, NULL);
    kfree(in_buffer);
    if (bytes_written < 0)
    {
        printk(KERN_ERR "Failed to write output file: %s\n", output_file);
        return bytes_written;
    }
    if (bytes_written != bytes_read)
    {
        printk(KERN_ERR "Mismatch in written bytes (%zd) and read bytes (%zd)\n",
               bytes_written, bytes_read);
        return -EIO;
    }

    printk(KERN_INFO "Decrypted/authenticated image written to: %s\n", output_file);

    return ret;
}

static int __init summit_prov_decrypt_init(void)
{
    int ret = -EINVAL;
    struct ti_sci_info *sci_info;

    printk(KERN_INFO "Summit Provisioning Decryption Module Loaded\n");

    enum k3_device_type dev_type = get_device_type();
    if (dev_type == K3_DEVICE_TYPE_BAD)
    {
        printk(KERN_ERR "Failed to determine device type\n");
        return -EINVAL;
    }

    printk(KERN_INFO "Input file: %s, output file: %s\n", input_file, output_file);

    memset(&soc_info, 0, sizeof(soc_info));

    sci_info = &soc_info.sci_info;

    sci_info->sp_info[MAIN_SEC_PROXY] = am62x_main_sp_info;
    sci_info->num_sp_threads[MAIN_SEC_PROXY] = AM62X_MAIN_SEC_PROXY_THREADS;
    sci_info->sp_info[MCU_SEC_PROXY] = NULL;
    sci_info->num_sp_threads[MCU_SEC_PROXY] = 0;
    sci_info->host_info = am62x_host_info;
    sci_info->num_hosts = AM62X_MAX_HOST_IDS;
    soc_info.host_id = DEFAULT_HOST_ID;
    soc_info.sec_proxy = &k3_lite_sec_proxy_base;
    soc_info.protocol = TISCI;

    if (!k3_sec_proxy_init())
    {
        soc_info.ti_sci_enabled = 1;
    }

    ret = decrypt_image(dev_type);

    if (ret)
    {
        printk(KERN_ERR "Image decryption failed: %d\n", ret);
    }
    else
    {
        printk(KERN_INFO "Image decryption succeeded\n");
    }

    return 0;
}

static void __exit summit_prov_decrypt_exit(void)
{
    printk(KERN_INFO "Summit Provisioning Decryption Module Unloaded\n");
}

module_init(summit_prov_decrypt_init);
module_exit(summit_prov_decrypt_exit);

MODULE_DESCRIPTION("Summit Provisioning Decryption Module");
MODULE_AUTHOR("Chris Trowbridge <chris.trowbridge@ezurio.com>");
MODULE_LICENSE("GPL");
