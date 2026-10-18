#!/usr/bin/env python3
import sys

from qiling import Qiling
from qiling.const import QL_VERBOSE


if __name__ == "__main__":

    if len(sys.argv) < 2:
        print("Usage : {0} BIN_FILE".format(sys.argv[0]))
        exit(0)

    f_name = sys.argv[1]
    # Les fichiers ouverts par le programme (vault.db) sont crees dans ./rootfs
    ql = Qiling([f_name], r'./rootfs', verbose=QL_VERBOSE.OFF, console=True)
    ql.run()
