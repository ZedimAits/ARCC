// ─────────────────────────────────────────────────────────────────────
// SPDX-License-Identifier: Apache-2.0
//
// ARCC - Advanced Retargetable Compiler Collection - Version 0.1.0
//
// Copyright (C) 2026 Cedric Beck
// Copyright (C) 2026 Felix Koppe <fkoppe@web.de>
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// ─────────────────────────────────────────────────────────────────────

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

extern int32_t arcc_main(void);

#ifdef __cplusplus
}
#endif

int main(int argc, char **argv) {
    (void)argc;
    (void)argv;

    return (int)arcc_main();
}
