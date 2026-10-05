#include <zephyr/kernel.h>
#include <zephyr/sys/reboot.h>
#include <psa/protected_storage.h>
#include <stdio.h>

#define SENTINEL_UID 0x1001

static const char sentinel[] = "persisted-across-reset";

int main(void)
{
	psa_status_t status;
	char buf[sizeof(sentinel)] = { 0 };
	size_t len = 0;

	printf("PS persistence probe\n");

	status = psa_ps_get(SENTINEL_UID, 0, sizeof(buf), buf, &len);

	if (status == PSA_SUCCESS) {
		printf("SURVIVED: read back '%s' (%u bytes)\n", buf, (unsigned int)len);
		return 0;
	}

	if (status != PSA_ERROR_DOES_NOT_EXIST) {
		printf("UNEXPECTED: psa_ps_get returned %d\n", (int)status);
		return 0;
	}

	printf("first boot: sentinel absent, writing it\n");

	status = psa_ps_set(SENTINEL_UID, sizeof(sentinel), sentinel, 0);
	if (status != PSA_SUCCESS) {
		printf("FAILED: psa_ps_set returned %d\n", (int)status);
		return 0;
	}

	printf("wrote sentinel, resetting now\n");
	k_sleep(K_MSEC(100));

	sys_reboot(SYS_REBOOT_COLD);

	printf("NOT-RESET: sys_reboot returned, non-secure reset refused\n");
	return 0;
}
