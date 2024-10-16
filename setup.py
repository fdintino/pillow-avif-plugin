import ast
from io import open
import os
import sys

from setuptools import Extension, setup


def version():
    filename = "src/pillow_avif/__init__.py"
    with open(filename) as f:
        tree = ast.parse(f.read(), filename)
    for node in tree.body:
        if isinstance(node, ast.Assign) and len(node.targets) == 1:
            (target,) = node.targets
            if isinstance(target, ast.Name) and target.id == "__version__":
                return node.value.s


def readme():
    try:
        with open("README.md") as f:
            return f.read()
    except IOError:
        pass


IS_DEBUG = hasattr(sys, "gettotalrefcount")
PLATFORM_MINGW = os.name == "nt" and "GCC" in sys.version

libraries = ["avif"]
if sys.platform == "win32":
    libraries.extend(
        [
            "advapi32",
            "bcrypt",
            "ntdll",
            "userenv",
            "ws2_32",
            "kernel32",
        ]
    )

test_requires = [
    "pytest",
    "packaging",
    "pytest-cov",
    "test-image-results",
    "pillow",
]

setup(
    name="pillow-avif-plugin",
    description="A pillow plugin that adds avif support via libavif",
    long_description=readme(),
    long_description_content_type="text/markdown",
    version=version(),
    ext_modules=[
        Extension(
            "pillow_avif._avif",
            ["src/pillow_avif/_avif.c"],
            depends=["avif/avif.h"],
            libraries=libraries,
        ),
    ],
    package_data={"": ["README.rst"]},
    package_dir={"": "src"},
    packages=["pillow_avif"],
    license="MIT License",
    author="Frankie Dintino",
    author_email="fdintino@theatlantic.com",
    url="https://github.com/fdintino/pillow-avif-plugin/",
    download_url="https://github.com/fdintino/pillow-avif-plugin/releases",
    install_requires=[],
    extras_require={"tests": test_requires},
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Environment :: Web Environment",
        "Intended Audience :: Developers",
        "License :: OSI Approved :: MIT License",
        "Operating System :: OS Independent",
        "Programming Language :: C",
        "Programming Language :: C++",
        "Programming Language :: Python :: 2.7",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.7",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: Implementation :: CPython",
        "Programming Language :: Python :: Implementation :: PyPy",
        "Topic :: Multimedia :: Graphics",
        "Topic :: Multimedia :: Graphics :: Graphics Conversion",
    ],
    zip_safe=not (IS_DEBUG or PLATFORM_MINGW),
)
