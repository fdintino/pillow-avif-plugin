from __future__ import annotations

import argparse
import os
import platform
import re
import shutil
import struct
import subprocess


def cmd_cd(path: str) -> str:
    return f"cd /D {path}"


def cmd_set(name: str, value: str) -> str:
    return f"set {name}={value}"


def cmd_append(name: str, value: str) -> str:
    op = "path " if name == "PATH" else f"set {name}="
    return op + f"%{name}%;{value}"


def cmd_copy(src: str, tgt: str) -> str:
    return f'copy /Y /B "{src}" "{tgt}"'


def cmd_xcopy(src: str, tgt: str) -> str:
    return f'xcopy /Y /E "{src}" "{tgt}"'


def cmd_mkdir(path: str) -> str:
    return f'mkdir "{path}"'


def cmd_rmdir(path: str) -> str:
    return f'rmdir /S /Q "{path}"'


def cmd_lib_combine(outfile: str, *libfiles) -> str:
    params = " ".join(['"%s"' % f for f in libfiles])
    return "LIB.EXE /OUT:{outfile} {params}".format(outfile=outfile, params=params)


def cmd_nmake(
    makefile: str | None = None,
    target: str = "",
    params: list[str] | None = None,
) -> str:
    params = "" if params is None else " ".join(params)

    return " ".join(
        [
            "{nmake}",
            "-nologo",
            f'-f "{makefile}"' if makefile is not None else "",
            f"{params}",
            f'"{target}"',
        ]
    )


def cmds_cmake(target: str | tuple[str, ...] | list[str], *params) -> list[str]:
    if not isinstance(target, str):
        target = " ".join(target)

    return [
        " ".join(
            [
                "{cmake}",
                "-DCMAKE_BUILD_TYPE=Release",
                "-DCMAKE_VERBOSE_MAKEFILE=ON",
                "-DCMAKE_RULE_MESSAGES:BOOL=OFF",  # for NMake
                "-DCMAKE_C_COMPILER=cl.exe",  # for Ninja
                "-DCMAKE_CXX_COMPILER=cl.exe",  # for Ninja
                "-DCMAKE_C_FLAGS=-nologo",
                "-DCMAKE_CXX_FLAGS=-nologo",
                *params,
                '-G "{cmake_generator}"',
                ".",
            ]
        ),
        f"{{cmake}} --build . --clean-first --parallel --target {target}",
    ]


def cmd_msbuild(
    file: str,
    configuration: str = "Release",
    target: str = "Build",
    platform: str = "{msbuild_arch}",
) -> str:
    return " ".join(
        [
            "{msbuild}",
            f"{file}",
            f'/t:"{target}"',
            f'/p:Configuration="{configuration}"',
            f"/p:Platform={platform}",
            "/m",
        ]
    )


SF_PROJECTS = "https://sourceforge.net/projects"

ARCHITECTURES = {
    "x86": {"vcvars_arch": "x86", "msbuild_arch": "Win32"},
    "x64": {"vcvars_arch": "x86_amd64", "msbuild_arch": "x64"},
    "ARM64": {"vcvars_arch": "x86_arm64", "msbuild_arch": "ARM64"},
}

# dependencies, listed in order of compilation
DEPS = {
    "libjpeg": {
        "url": SF_PROJECTS
        + "/libjpeg-turbo/files/3.0.0/libjpeg-turbo-3.0.0.tar.gz/download",
        "filename": "libjpeg-turbo-3.0.0.tar.gz",
        "dir": "libjpeg-turbo-3.0.0",
        "license": ["README.ijg", "LICENSE.md"],
        "license_pattern": (
            "(LEGAL ISSUES\n============\n\n.+?)\n\nREFERENCES\n=========="
            ".+(libjpeg-turbo Licenses\n======================\n\n.+)$"
        ),
        "build": [
            *cmds_cmake(
                ("jpeg-static", "cjpeg-static", "djpeg-static"),
                "-DENABLE_SHARED:BOOL=FALSE",
                "-DWITH_JPEG8:BOOL=TRUE",
                "-DWITH_CRT_DLL:BOOL=TRUE",
            ),
            cmd_copy("jpeg-static.lib", "libjpeg.lib"),
            cmd_copy("cjpeg-static.exe", "cjpeg.exe"),
            cmd_copy("djpeg-static.exe", "djpeg.exe"),
        ],
        "headers": ["j*.h"],
        "libs": ["libjpeg.lib"],
        "bins": ["cjpeg.exe", "djpeg.exe"],
    },
    "zlib": {
        "url": "https://zlib.net/zlib13.zip",
        "filename": "zlib13.zip",
        "dir": "zlib-1.3",
        "license": "README",
        "license_pattern": "Copyright notice:\n\n(.+)$",
        "build": [
            cmd_nmake(r"win32\Makefile.msc", "clean"),
            cmd_nmake(r"win32\Makefile.msc", "zlib.lib"),
            cmd_copy("zlib.lib", "z.lib"),
        ],
        "headers": [r"z*.h"],
        "libs": [r"*.lib"],
    },
    "libpng": {
        "url": SF_PROJECTS + "/libpng/files/libpng16/1.6.39/lpng1639.zip/download",
        "filename": "lpng1639.zip",
        "dir": "lpng1639",
        "license": "LICENSE",
        "build": [
            *cmds_cmake("png_static", "-DPNG_SHARED:BOOL=OFF", "-DPNG_TESTS:BOOL=OFF"),
            cmd_copy("libpng16_static.lib", "libpng16.lib"),
        ],
        "headers": [r"png*.h"],
        "libs": [r"libpng16.lib"],
    },
    "rav1e": {
        "url": (
            "https://github.com/xiph/rav1e/releases/download/p20231003/"
            "rav1e-windows-msvc-generic.zip"
        ),
        "filename": "rav1e-windows-msvc-generic.zip",
        "dir": "rav1e-windows-msvc-sdk",
        "license": "LICENSE",
        "build": [
            cmd_xcopy("include", "{inc_dir}"),
        ],
        "bins": [r"bin\*.dll"],
        "libs": [r"lib\*.*"],
    },
    "libavif": {
        "url": (
            "https://github.com/fdintino/libavif/archive/"
            "88d3dccda111f6ccbcccd925179f67e7d6fdf4ff.zip"
        ),
        "filename": "libavif-88d3dccda111f6ccbcccd925179f67e7d6fdf4ff.zip",
        "dir": "libavif-88d3dccda111f6ccbcccd925179f67e7d6fdf4ff",
        "license": "LICENSE",
        "build": [
            cmd_mkdir("build.pillow"),
            cmd_cd("build.pillow"),
            " ".join(
                [
                    "{cmake}",
                    "-DCMAKE_BUILD_TYPE=Release",
                    "-DCMAKE_VERBOSE_MAKEFILE=ON",
                    "-DCMAKE_RULE_MESSAGES:BOOL=OFF",  # for NMake
                    "-DCMAKE_C_COMPILER=cl.exe",  # for Ninja
                    "-DCMAKE_CXX_COMPILER=cl.exe",  # for Ninja
                    "-DCMAKE_C_FLAGS=-nologo",
                    "-DCMAKE_CXX_FLAGS=-nologo",
                    "-DBUILD_SHARED_LIBS=OFF",
                    "-DAVIF_CODEC_AOM=ON",
                    "-DAVIF_LOCAL_AOM=ON",
                    "-DAVIF_LOCAL_LIBYUV=ON",
                    "-DAVIF_LOCAL_LIBSHARPYUV=ON",
                    "-DAVIF_CODEC_RAV1E=ON",
                    "-DAVIF_RAV1E_ROOT={build_dir}",
                    "-DCMAKE_MODULE_PATH={winbuild_dir_cmake}",
                    "-DAVIF_CODEC_DAV1D=ON",
                    "-DAVIF_LOCAL_DAV1D=ON",
                    "-DAVIF_CODEC_SVT=ON",
                    "-DAVIF_LOCAL_SVT=ON",
                    '-G "Ninja"',
                    "..",
                ]
            ),
            "ninja -v",
            cmd_cd(".."),
            cmd_xcopy("include", "{inc_dir}"),
        ],
        "libs": [r"build.pillow\avif.lib"],
    },
}


# based on distutils._msvccompiler from CPython 3.7.4
def find_msvs() -> dict[str, str] | None:
    root = os.environ.get("ProgramFiles(x86)") or os.environ.get("ProgramFiles")
    if not root:
        print("Program Files not found")
        return None

    try:
        vspath = (
            subprocess.check_output(
                [
                    os.path.join(
                        root, "Microsoft Visual Studio", "Installer", "vswhere.exe"
                    ),
                    "-latest",
                    "-prerelease",
                    "-requires",
                    "Microsoft.VisualStudio.Component.VC.Tools.x86.x64",
                    "-property",
                    "installationPath",
                    "-products",
                    "*",
                ]
            )
            .decode(encoding="mbcs")
            .strip()
        )
    except (subprocess.CalledProcessError, OSError, UnicodeDecodeError):
        print("vswhere not found")
        return None

    if not os.path.isdir(os.path.join(vspath, "VC", "Auxiliary", "Build")):
        print("Visual Studio seems to be missing C compiler")
        return None

    # vs2017
    msbuild = os.path.join(vspath, "MSBuild", "15.0", "Bin", "MSBuild.exe")
    if not os.path.isfile(msbuild):
        # vs2019
        msbuild = os.path.join(vspath, "MSBuild", "Current", "Bin", "MSBuild.exe")
        if not os.path.isfile(msbuild):
            print("Visual Studio MSBuild not found")
            return None

    vcvarsall = os.path.join(vspath, "VC", "Auxiliary", "Build", "vcvarsall.bat")
    if not os.path.isfile(vcvarsall):
        print("Visual Studio vcvarsall not found")
        return None

    return {
        "vs_dir": vspath,
        "msbuild": f'"{msbuild}"',
        "vcvarsall": f'"{vcvarsall}"',
        "nmake": "nmake.exe",  # nmake selected by vcvarsall
    }


def download_dep(url: str, file: str) -> None:
    import urllib.request

    ex = None
    for i in range(3):
        try:
            print(f"Fetching {url} (attempt {i + 1})...")
            content = urllib.request.urlopen(url).read()
            with open(file, "wb") as f:
                f.write(content)
            break
        except urllib.error.URLError as e:
            ex = e
    else:
        raise RuntimeError(ex)


def extract_dep(url: str, filename: str) -> None:
    import tarfile
    import zipfile

    file = os.path.join(args.depends_dir, filename)
    if not os.path.exists(file):
        # First try our mirror
        mirror_url = (
            f"https://raw.githubusercontent.com/"
            f"python-pillow/pillow-depends/main/{filename}"
        )
        try:
            download_dep(mirror_url, file)
        except RuntimeError as exc:
            # Otherwise try upstream
            print(exc)
            download_dep(url, file)

    print("Extracting " + filename)
    sources_dir_abs = os.path.abspath(sources_dir)
    if filename.endswith(".zip"):
        with zipfile.ZipFile(file) as zf:
            for member in zf.namelist():
                member_abspath = os.path.abspath(os.path.join(sources_dir, member))
                member_prefix = os.path.commonpath([sources_dir_abs, member_abspath])
                if sources_dir_abs != member_prefix:
                    msg = "Attempted Path Traversal in Zip File"
                    raise RuntimeError(msg)
            zf.extractall(sources_dir)
    elif filename.endswith(".tar.gz") or filename.endswith(".tgz"):
        with tarfile.open(file, "r:gz") as tgz:
            for member in tgz.getnames():
                member_abspath = os.path.abspath(os.path.join(sources_dir, member))
                member_prefix = os.path.commonpath([sources_dir_abs, member_abspath])
                if sources_dir_abs != member_prefix:
                    msg = "Attempted Path Traversal in Tar File"
                    raise RuntimeError(msg)
            tgz.extractall(sources_dir)
    else:
        msg = "Unknown archive type: " + filename
        raise RuntimeError(msg)


def write_script(name: str, lines: list[str]) -> None:
    name = os.path.join(args.build_dir, name)
    lines = [line.format(**prefs) for line in lines]
    print("Writing " + name)
    with open(name, "w", newline="") as f:
        f.write(os.linesep.join(lines))
    if args.verbose:
        for line in lines:
            print("    " + line)


def get_footer(dep: dict) -> list[str]:
    lines = []
    for out in dep.get("headers", []):
        lines.append(cmd_copy(out, "{inc_dir}"))
    for out in dep.get("libs", []):
        lines.append(cmd_copy(out, "{lib_dir}"))
    for out in dep.get("bins", []):
        lines.append(cmd_copy(out, "{bin_dir}"))
    return lines


def build_env() -> None:
    lines = [
        "if defined DISTUTILS_USE_SDK goto end",
        cmd_set("INCLUDE", "{inc_dir}"),
        cmd_set("INCLIB", "{lib_dir}"),
        cmd_set("LIB", "{lib_dir}"),
        cmd_append("PATH", "{bin_dir}"),
        "call {vcvarsall} {vcvars_arch}",
        cmd_set("DISTUTILS_USE_SDK", "1"),  # use same compiler to build Pillow
        cmd_set("py_vcruntime_redist", "true"),  # always use /MD, never /MT
        ":end",
        "@echo on",
    ]
    write_script("build_env.cmd", lines)


def build_dep(name: str) -> str:
    dep = DEPS[name]
    dir = dep["dir"]
    file = f"build_dep_{name}.cmd"

    extract_dep(dep["url"], dep["filename"])

    licenses = dep["license"]
    if isinstance(licenses, str):
        licenses = [licenses]
    license_text = ""
    for license_file in licenses:
        with open(os.path.join(sources_dir, dir, license_file)) as f:
            license_text += f.read()
    if "license_pattern" in dep:
        match = re.search(dep["license_pattern"], license_text, re.DOTALL)
        license_text = "\n".join(match.groups())
    if licenses:
        assert len(license_text) > 50
        with open(os.path.join(license_dir, f"{dir}.txt"), "w") as f:
            print(f"Writing license {dir}.txt")
            f.write(license_text)

    for patch_file, patch_list in dep.get("patch", {}).items():
        patch_file = os.path.join(sources_dir, dir, patch_file.format(**prefs))
        with open(patch_file) as f:
            text = f.read()
        for patch_from, patch_to in patch_list.items():
            patch_from = patch_from.format(**prefs)
            patch_to = patch_to.format(**prefs)
            assert patch_from in text
            text = text.replace(patch_from, patch_to)
        with open(patch_file, "w") as f:
            print(f"Patching {patch_file}")
            f.write(text)

    banner = f"Building {name} ({dir})"
    lines = [
        r'call "{build_dir}\build_env.cmd"',
        "@echo " + ("=" * 70),
        f"@echo ==== {banner:<60} ====",
        "@echo " + ("=" * 70),
        cmd_cd(os.path.join(sources_dir, dir)),
        *dep.get("build", []),
        *get_footer(dep),
    ]

    write_script(file, lines)
    return file


def build_dep_all() -> None:
    lines = [r'call "{build_dir}\build_env.cmd"']
    for dep_name in DEPS:
        print()
        if dep_name in disabled:
            print(f"Skipping disabled dependency {dep_name}")
            continue
        script = build_dep(dep_name)
        lines.append(rf'cmd.exe /c "{{build_dir}}\{script}"')
        lines.append("if errorlevel 1 echo Build failed! && exit /B 1")
    print()
    lines.append("@echo All Pillow dependencies built successfully!")
    write_script("build_dep_all.cmd", lines)


def install_meson():
    msi_url = "https://github.com/mesonbuild/meson/releases/download/0.56.2/meson-0.56.2-64.msi"  # noqa: E501
    msi_file = os.path.join(args.depends_dir, "meson-0.56.2-64.msi")
    download_dep(msi_url, msi_file)

    lines = [
        "@echo on",
        "@echo ---- Installing meson ----",
        "msiexec /q /i %s" % msi_file,
        "@echo meson installed successfully",
    ]
    write_script("install_meson.cmd", lines)


if __name__ == "__main__":
    winbuild_dir = os.path.dirname(os.path.realpath(__file__))
    pillow_dir = os.path.realpath(os.path.join(winbuild_dir, ".."))

    parser = argparse.ArgumentParser(
        prog="winbuild\\build_prepare.py",
        description="Download and generate build scripts for Pillow dependencies.",
        epilog="""Arguments can also be supplied using the environment variables
                  PILLOW_BUILD, PILLOW_DEPS, ARCHITECTURE. See winbuild\\build.rst
                  for more information.""",
    )
    parser.add_argument(
        "-v", "--verbose", action="store_true", help="print generated scripts"
    )
    parser.add_argument(
        "-d",
        "--dir",
        "--build-dir",
        dest="build_dir",
        metavar="PILLOW_BUILD",
        default=os.environ.get("PILLOW_BUILD", os.path.join(winbuild_dir, "build")),
        help="build directory (default: 'winbuild\\build')",
    )
    parser.add_argument(
        "--depends",
        dest="depends_dir",
        metavar="PILLOW_DEPS",
        default=os.environ.get("PILLOW_DEPS", os.path.join(winbuild_dir, "depends")),
        help="directory used to store cached dependencies "
        "(default: 'winbuild\\depends')",
    )
    parser.add_argument(
        "--architecture",
        choices=ARCHITECTURES,
        default=os.environ.get(
            "ARCHITECTURE",
            (
                "ARM64"
                if platform.machine() == "ARM64"
                else ("x86" if struct.calcsize("P") == 4 else "x64")
            ),
        ),
        help="build architecture (default: same as host Python)",
    )
    parser.add_argument(
        "--nmake",
        dest="cmake_generator",
        action="store_const",
        const="NMake Makefiles",
        default="Ninja",
        help="build dependencies using NMake instead of Ninja",
    )
    args = parser.parse_args()

    arch_prefs = ARCHITECTURES[args.architecture]
    print("Target architecture:", args.architecture)

    msvs = find_msvs()
    if msvs is None:
        msg = "Visual Studio not found. Please install Visual Studio 2017 or newer."
        raise RuntimeError(msg)
    print("Found Visual Studio at:", msvs["vs_dir"])

    # dependency cache directory
    args.depends_dir = os.path.abspath(args.depends_dir)
    os.makedirs(args.depends_dir, exist_ok=True)
    print("Caching dependencies in:", args.depends_dir)

    args.build_dir = os.path.abspath(args.build_dir)
    print("Using output directory:", args.build_dir)

    # build directory for *.h files
    inc_dir = os.path.join(args.build_dir, "inc")
    # build directory for *.lib files
    lib_dir = os.path.join(args.build_dir, "lib")
    # build directory for *.bin files
    bin_dir = os.path.join(args.build_dir, "bin")
    # directory for storing project files
    sources_dir = os.path.join(args.build_dir, "src")
    # copy dependency licenses to this directory
    license_dir = os.path.join(args.build_dir, "license")

    shutil.rmtree(args.build_dir, ignore_errors=True)
    os.makedirs(args.build_dir, exist_ok=False)
    for path in [inc_dir, lib_dir, bin_dir, sources_dir, license_dir]:
        os.makedirs(path, exist_ok=True)

    disabled = []

    prefs = {
        "architecture": args.architecture,
        **arch_prefs,
        # Pillow paths
        "pillow_dir": pillow_dir,
        "winbuild_dir": winbuild_dir,
        "winbuild_dir_cmake": winbuild_dir.replace("\\", "/"),
        # Build paths
        "build_dir": args.build_dir,
        "inc_dir": inc_dir,
        "lib_dir": lib_dir,
        "bin_dir": bin_dir,
        "src_dir": sources_dir,
        "license_dir": license_dir,
        # Compilers / Tools
        **msvs,
        "cmake": "cmake.exe",  # TODO find CMAKE automatically
        "cmake_generator": args.cmake_generator,
        # TODO find NASM automatically
    }

    for k, v in DEPS.items():
        prefs[f"dir_{k}"] = os.path.join(sources_dir, v["dir"])

    print()

    write_script(".gitignore", ["*"])
    build_env()
    install_meson()
    build_dep_all()
