#include <zephyr/kernel.h>
#include <stdint.h>
#include <stdio.h>

/* NS primary slot start, TF-M AN521 flash_layout.h */
#define NS_SLOT_ADDR 0x00100000

/* MCUboot magic numbers, and the entry types this app prints (hash, key, signature) */
#define IMAGE_MAGIC          0x96f3b83d
#define IMAGE_TLV_INFO_MAGIC 0x6907
#define IMAGE_TLV_PUBKEY     0x02
#define IMAGE_TLV_SHA256     0x10
#define IMAGE_TLV_ECDSA_SIG  0x22

/* MCUboot image layout: [ header | firmware | hash, key, signature ] */
struct image_version {
	uint8_t major;
	uint8_t minor;
	uint16_t revision;
	uint32_t build;
} __packed;

struct image_header {
	uint32_t magic;
	uint32_t load_addr;
	uint16_t hdr_size;
	uint16_t protect_tlv_size;
	uint32_t img_size;
	uint32_t flags;
	struct image_version ver;
	uint32_t pad;
} __packed;

struct image_tlv_info {
	uint16_t magic;
	uint16_t tlv_tot;
} __packed;

struct image_tlv {
	uint16_t type;
	uint16_t len;
} __packed;

/* Print a byte buffer as hex */
static void print_hex(const uint8_t *data, size_t len)
{
	for (size_t i = 0; i < len; i++) {
		printf("%02x", data[i]);
	}
	printf("\n");
}

int main(void)
{
	/* The header sits at the very start of this app's own flash slot */
	const struct image_header *hdr = (const struct image_header *)NS_SLOT_ADDR;

	printf("Image header @ 0x%08x\n", NS_SLOT_ADDR);
	printf("  magic     : 0x%08x\n", hdr->magic);
	if (hdr->magic != IMAGE_MAGIC) {
		printf("  not an MCUboot image\n");
		return 0;
	}
	/* Version and firmware size, set at signing time */
	printf("  version   : %u.%u.%u+%u\n", hdr->ver.major, hdr->ver.minor,
	       hdr->ver.revision, hdr->ver.build);
	printf("  size      : %u bytes\n", hdr->img_size);

	/* After the firmware: a list of entries (type, length, data), the TLV area */
	uintptr_t tlv_start = NS_SLOT_ADDR + hdr->hdr_size + hdr->img_size +
			      hdr->protect_tlv_size;
	const struct image_tlv_info *info = (const struct image_tlv_info *)tlv_start;

	if (info->magic != IMAGE_TLV_INFO_MAGIC) {
		printf("  no TLV area found\n");
		return 0;
	}

	/* Read the entries one by one and print the hash, public key and signature */
	uintptr_t p = tlv_start + sizeof(*info);
	uintptr_t end = tlv_start + info->tlv_tot;

	while (p < end) {
		const struct image_tlv *tlv = (const struct image_tlv *)p;
		const uint8_t *data = (const uint8_t *)(p + sizeof(*tlv));

		switch (tlv->type) {
		case IMAGE_TLV_SHA256:
			printf("  SHA256    : ");
			print_hex(data, tlv->len);
			break;
		case IMAGE_TLV_PUBKEY:
			printf("  public key: %u bytes\n", tlv->len);
			break;
		case IMAGE_TLV_ECDSA_SIG:
			printf("  signature : ECDSA, %u bytes\n", tlv->len);
			break;
		default:
			break;
		}
		p += sizeof(*tlv) + tlv->len;
	}

	/* Reaching this line means BL2 accepted the image */
	printf("Hello from the signed app\n");
	return 0;
}
