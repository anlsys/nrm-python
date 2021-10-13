#!/usr/bin/env python3

# START_LICENSE
###############################################################################
# Copyright 2019 UChicago Argonne, LLC.
# (c.f. AUTHORS, LICENSE)
#
# This file is part of the NRM project.
# For more info, see https://xgitlab.cels.anl.gov/argo/nrm
#
# SPDX-License-Identifier: BSD-3-Clause
###############################################################################
# END_LICENSE

import os
import glob

# Paste desired license for each python file between above tags
with open(__file__) as f:
    lines = f.readlines()
    lic_start_idx = lines.index("# START_LICENSE\n") + 1
    lic_end_indx = lines.index("# END_LICENSE\n")
    license = lines[lic_start_idx:lic_end_indx]

fail_files = []
for pyfile in glob.glob('../*/*.py') + glob.glob('../bin/*'):
    with open(pyfile) as f:
        lines = f.readlines()
        if not all([i in lines for i in license]):
            fail_files.append(pyfile)

assert not len(fail_files), \
    "The following project Python files do not contain the project's license:\n" + "\n".join(fail_files)
