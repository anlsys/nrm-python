#!/usr/bin/env python3

import sys
import nbformat
import subprocess
from nbconvert.preprocessors import ExecutePreprocessor
import glob
from os.path import basename

f = sys.argv[1]
nb = nbformat.read(open(f), as_version=4)
ep = ExecutePreprocessor(timeout=600, kernel_name="python3")
ep.preprocess(nb, {"metadata": {"path": "notebooks/"}})
nbformat.write(nb, open("doc/notebooks/notebooks/%s" % basename(f), mode="wt"))
