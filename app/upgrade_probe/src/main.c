#include <zephyr/kernel.h>
#include <stdio.h>

int main(void)
{
	printf("upgrade probe: APP VERSION %d\n", APP_VERSION);
	return 0;
}
