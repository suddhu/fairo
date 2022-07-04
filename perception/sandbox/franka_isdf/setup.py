# Copyright (c) Meta Platforms, Inc. and affiliates.
# All rights reserved.

# This source code is licensed under the license found in the
# LICENSE file in the root directory of this source tree.

from gettext import install
from setuptools import setup, find_packages

__author__ = "Sudharshan Suresh"
__copyright__ = "2022, Meta"

install_requires = [
    "mrp",
    "open3d",
    "pyvista",
    "pyvistaqt",
    "fairomsg",
    "realsense_wrapper",
]

setup(
    name="franka_isdf",
    author="Sudharshan Suresh",
    author_email="suddhu@fb.com",
    version="0.1",
    packages=find_packages(where="src"),
    package_dir={"": "src"},
    include_package_data=True,
    scripts=["scripts/run_isdf.py"],
    install_requires = install_requires
)