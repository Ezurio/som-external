/*
 * SPDX-License-Identifier: LicenseRef-Ezurio-Clause
 * Copyright (C) 2025 Ezurio LLC.
 */

#ifndef SUMMIT_PROV_DECRYPT_H
#define SUMMIT_PROV_DECRYPT_H

#include <linux/init.h>
#include <linux/module.h>
#include <linux/io.h>
#include <linux/kernel.h>
#include <linux/moduleparam.h>
#include <linux/dma-mapping.h>
#include <linux/fs.h>
#include <linux/key.h>
#include <linux/cred.h>
#include <linux/crypto.h>
#include <crypto/skcipher.h>
#include <linux/scatterlist.h>
#include <linux/slab.h>
#include <keys/user-type.h>

#define MAX_INPUT_FILE_SIZE (1024 * 1024) // 1 MB

#define SUMMIT_PROV_DECRYPT_KEY_DESC "summit_prov_decrypt_key"
#define SUMMIT_PROV_DECRYPT_IV_DESC "summit_prov_decrypt_iv"
#define AES_KEY_SIZE 32         /* 256 bits */
#define AES_BLOCK_SIZE 16

#define TISCI_ADDR_LOW_MASK GENMASK_ULL(31, 0)
#define TISCI_ADDR_HIGH_MASK GENMASK_ULL(63, 32)
#define TISCI_ADDR_HIGH_SHIFT 32

#define DEFAULT_HOST_ID 13

#define SEC_PROXY_MAX_MSG_SIZE 60
#define SEC_PROXY_RECV_MAX_RETRIES 10000

#define TABLE_MAX_ELT_LEN 100

#define AM62X_MAIN_SEC_PROXY_THREADS 35

struct ti_sci_caps_info
{
	u8 valid;
	u64 fw_caps;
};

struct ti_sci_dm_version_info
{
	u8 valid;
	u16 dm_version;
	u8 sub_version;
	u8 patch_version;
	u8 abi_major;
	u8 abi_minor;
	char rm_pm_hal_version[12];
	char sci_server_version[26];
};

struct ti_sci_version_info
{
	u8 abi_major;
	u8 abi_minor;
	u16 firmware_version;
	char firmware_description[32];
	struct ti_sci_caps_info caps_info;
	struct ti_sci_dm_version_info dm_info;
};

struct ti_sci_host_info
{
	u32 host_id;
	char host_name[15];
	char security_status[15];
	char description[50];
};

#define MAIN_SEC_PROXY 0
#define MCU_SEC_PROXY 1

struct ti_sci_sec_proxy_info
{
	u32 sp_id;
	char sp_dir[6];
	u32 num_msgs;
	char host[15];
	char host_function[50];
};

struct ti_sci_processors_info
{
	u32 dev_id;
	u32 clk_id;
	u32 processor_id;
	char name[30];
};

struct ti_sci_devices_info
{
	u32 dev_id;
	char name[60];
};

struct ti_sci_clocks_info
{
	u32 dev_id;
	u32 clk_id;
	char clk_name[100];
	char clk_function[100];
};

struct ti_sci_rm_info
{
	u32 utype;
	char subtype_name[100];
};

struct ti_sci_info
{
	u8 host_id;
	struct ti_sci_version_info version;
	struct ti_sci_host_info *host_info;
	u32 num_hosts;
	struct ti_sci_sec_proxy_info *sp_info[2];
	u32 num_sp_threads[2];
	struct ti_sci_processors_info *processors_info;
	u32 num_processors;
	struct ti_sci_devices_info *devices_info;
	u32 num_devices;
	struct ti_sci_clocks_info *clocks_info;
	u32 num_clocks;
	struct ti_sci_rm_info *rm_info;
	u32 num_res;
};

/* Processor Control Messages */
#define TI_SCI_MSG_PROC_AUTH_BOOT_IMAGE 0xc120

#define AM62X_MAX_HOST_IDS 16

/* SEC PROXY RT THREAD STATUS */
#define RT_THREAD_STATUS 0x0
#define RT_THREAD_THRESHOLD 0x4
#define RT_THREAD_STATUS_ERROR_SHIFT 31
#define RT_THREAD_STATUS_ERROR_MASK (1 << 31)
#define RT_THREAD_STATUS_CUR_CNT_SHIFT 0
#define RT_THREAD_STATUS_CUR_CNT_MASK 0xff

/* SEC PROXY SCFG THREAD CTRL */
#define SCFG_THREAD_CTRL 0x1000
#define SCFG_THREAD_CTRL_DIR_SHIFT 31
#define SCFG_THREAD_CTRL_DIR_MASK (1 << 31)

#define SEC_PROXY_THREAD(base, x) ((base) + (0x1000 * (x)))
#define SEC_PROXY_TX_THREAD 0
#define SEC_PROXY_RX_THREAD 1
#define SEC_PROXY_MAX_THREADS 2

#define SEC_PROXY_DATA_START_OFFS 0x4
#define SEC_PROXY_DATA_END_OFFS 0x3c

#define K3_SEC_MGR_SYS_STATUS		0x44234100
#define SYS_STATUS_DEV_TYPE_SHIFT	0
#define SYS_STATUS_DEV_TYPE_MASK	(0xf)
#define SYS_STATUS_DEV_TYPE_GP		0x3
#define SYS_STATUS_DEV_TYPE_TEST	0x5
#define SYS_STATUS_DEV_TYPE_EMU		0x9
#define SYS_STATUS_DEV_TYPE_HS		0xa
#define SYS_STATUS_SUB_TYPE_SHIFT	8
#define SYS_STATUS_SUB_TYPE_MASK	(0xf << 8)
#define SYS_STATUS_SUB_TYPE_VAL_FS	0xa

typedef enum
{
	TISCI,
	SCMI,
} comm_protocol;

enum k3_device_type {
	K3_DEVICE_TYPE_BAD,
	K3_DEVICE_TYPE_GP,
	K3_DEVICE_TYPE_TEST,
	K3_DEVICE_TYPE_EMU,
	K3_DEVICE_TYPE_HS_FS,
	K3_DEVICE_TYPE_HS_SE,
};

struct k3conf_soc_info
{
	const char *soc_name;
	const char *rev_name;
	char dev_part_identifier[TABLE_MAX_ELT_LEN];
	char die_id[TABLE_MAX_ELT_LEN];
	u8 host_id;
	u8 ti_sci_enabled;
	u8 scmi_enabled;
	comm_protocol protocol;
	struct ti_sci_info sci_info;
	struct ddr_perf_soc_info *ddr_perf_info;
	struct k3_sec_proxy_base *sec_proxy;
};

struct k3_sec_proxy_msg
{
	size_t len;
	u8 *buf;
};

struct k3_sec_proxy_base
{
	u32 src_target_data;
	u32 cfg_scfg;
	u32 cfg_rt;
};

/**
 * struct ti_sci_msg_hdr - Generic Message Header for All messages and responses
 * @type:	Type of messages: One of TI_SCI_MSG* values
 * @host:	Host of the message
 * @seq:	Message identifier indicating a transfer sequence
 * @flags:	Flag for the message
 */
struct ti_sci_msg_hdr
{
	u16 type;
	u8 host;
	u8 seq;
#define TI_SCI_MSG_FLAG(val) (1 << (val))
#define TI_SCI_FLAG_REQ_GENERIC_NORESPONSE 0x0
#define TI_SCI_FLAG_REQ_ACK_ON_RECEIVED TI_SCI_MSG_FLAG(0)
#define TI_SCI_FLAG_REQ_ACK_ON_PROCESSED TI_SCI_MSG_FLAG(1)
#define TI_SCI_FLAG_RESP_GENERIC_NACK 0x0
#define TI_SCI_FLAG_RESP_GENERIC_ACK TI_SCI_MSG_FLAG(1)
	/* Additional Flags */
	u32 flags;
} __packed;

/**
 * struct ti_sci_msg_req_proc_auth_start_image - Authenticate and start image
 * @hdr:		Generic Header
 * @cert_addr_low:	Lower 32bit (Little Endian) of certificate
 * @cert_addr_high:	Higher 32bit (Little Endian) of certificate
 *
 * Request type is TI_SCI_MSG_PROC_AUTH_BOOT_IMAGE, response is a generic
 * ACK/NACK message.
 */
struct ti_sci_msg_req_proc_auth_boot_image
{
	struct ti_sci_msg_hdr hdr;
	u32 cert_addr_low;
	u32 cert_addr_high;
} __packed;

struct ti_sci_msg_resp_proc_auth_boot_image
{
	struct ti_sci_msg_hdr hdr;
	u32 image_addr_low;
	u32 image_addr_high;
	u32 image_size;
} __packed;

void ti_sci_setup_header(struct ti_sci_msg_hdr *hdr, u16 type,
						 u32 flags);
int ti_sci_xfer_msg(struct k3_sec_proxy_msg *msg);

int k3_sec_proxy_send(struct k3_sec_proxy_msg *msg);
int k3_sec_proxy_recv(struct k3_sec_proxy_msg *msg);
int k3_sec_proxy_init(void);
int ti_sci_cmd_proc_auth_boot_image_file(void **p_image, size_t *p_size);
enum k3_device_type get_device_type(void);

/**
 * ti_sci_is_response_ack() - Generic ACK/NACK message checkup
 * @r:	pointer to response buffer
 *
 * Return: true if the response was an ACK, else returns false.
 */
static inline bool ti_sci_is_response_ack(void *r)
{
	struct ti_sci_msg_hdr *hdr = r;

	return hdr->flags & TI_SCI_FLAG_RESP_GENERIC_ACK ? true : false;
}

extern struct k3_sec_proxy_base k3_generic_sec_proxy_base;
extern struct k3_sec_proxy_base k3_lite_sec_proxy_base;
extern struct ti_sci_sec_proxy_info am62x_main_sp_info[];
extern struct ti_sci_sec_proxy_info am62x_mcu_sp_info[];
extern struct ti_sci_host_info am62x_host_info[];

#endif // SUMMIT_PROV_DECRYPT_H
