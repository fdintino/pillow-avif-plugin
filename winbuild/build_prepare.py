import os
import shutil
import struct
import subprocess
import sys


def cmd_cd(path):
    return "cd /D {path}".format(path=path)


def cmd_set(name, value):
    return "set {name}={value}".format(name=name, value=value)


def cmd_append(name, value):
    op = "path " if name == "PATH" else "set {name}=".format(name=name)
    return op + "%{name}%;{value}".format(name=name, value=value)


def cmd_copy(src, tgt):
    return 'copy /Y /B "{src}" "{tgt}"'.format(src=src, tgt=tgt)


def cmd_mkdir(path):
    return 'mkdir "{path}"'.format(path=path)


def cmd_rmdir(path):
    return 'rmdir /S /Q "{path}"'.format(path=path)


def cmd_lib_combine(outfile, *libfiles):
    params = " ".join(['"%s"' % f for f in libfiles])
    return "LIB.EXE /OUT:{outfile} {params}".format(outfile=outfile, params=params)


def cmd_nmake(makefile=None, target="", params=None):
    if params is None:
        params = ""
    elif isinstance(params, list) or isinstance(params, tuple):
        params = " ".join(params)
    else:
        params = str(params)

    if makefile is not None:
        makefile_arg = '-f "{makefile}"'.format(makefile=makefile)
    else:
        makefile_arg = ""

    return " ".join(
        [
            "{nmake}",
            "-nologo",
            makefile_arg,
            "{params}".format(params=params),
            '"{target}"'.format(target=target),
        ]
    )


def cmd_cmake(params=None, file="."):
    if params is None:
        params = ""
    elif isinstance(params, list) or isinstance(params, tuple):
        params = " ".join(params)
    else:
        params = str(params)
    return " ".join(
        [
            "{cmake}",
            "-DCMAKE_VERBOSE_MAKEFILE=ON",
            "-DCMAKE_RULE_MESSAGES:BOOL=OFF",
            "-DCMAKE_BUILD_TYPE=Release",
            "{params}".format(params=params),
            '-G "NMake Makefiles"',
            '"{file}"'.format(file=file),
        ]
    )


SF_MIRROR = "http://iweb.dl.sourceforge.net"

architectures = {
    "x86": {"vcvars_arch": "x86", "msbuild_arch": "Win32"},
    "x64": {"vcvars_arch": "x86_amd64", "msbuild_arch": "x64"},
}

header = [
    cmd_set("INCLUDE", "{inc_dir}"),
    cmd_set("INCLIB", "{lib_dir}"),
    cmd_set("LIB", "{lib_dir}"),
    cmd_append("PATH", "{bin_dir}"),
]

# dependencies, listed in order of compilation
deps = {
    "libjpeg": {
        "url": SF_MIRROR + "/project/libjpeg-turbo/2.0.6/libjpeg-turbo-2.0.6.tar.gz",
        "filename": "libjpeg-turbo-2.0.6.tar.gz",
        "dir": "libjpeg-turbo-2.0.6",
        "build": [
            cmd_cmake(
                [
                    "-DENABLE_SHARED:BOOL=FALSE",
                    "-DWITH_JPEG8:BOOL=TRUE",
                    "-DWITH_CRT_DLL:BOOL=TRUE",
                ]
            ),
            cmd_nmake(target="clean"),
            cmd_nmake(target="jpeg-static"),
            cmd_copy("jpeg-static.lib", "libjpeg.lib"),
            cmd_nmake(target="cjpeg-static"),
            cmd_copy("cjpeg-static.exe", "cjpeg.exe"),
            cmd_nmake(target="djpeg-static"),
            cmd_copy("djpeg-static.exe", "djpeg.exe"),
        ],
        "headers": ["j*.h"],
        "libs": ["libjpeg.lib"],
        "bins": ["cjpeg.exe", "djpeg.exe"],
    },
    "zlib": {
        "url": "http://zlib.net/zlib1211.zip",
        "filename": "zlib1211.zip",
        "dir": "zlib-1.2.11",
        "build": [
            cmd_nmake(r"win32\Makefile.msc", "clean"),
            cmd_nmake(r"win32\Makefile.msc", "zlib.lib"),
            cmd_copy("zlib.lib", "z.lib"),
        ],
        "headers": [r"z*.h"],
        "libs": [r"*.lib"],
    },
    "libpng": {
        "url": SF_MIRROR + "/project/libpng/libpng16/1.6.37/lpng1637.zip",
        "filename": "lpng1637.zip",
        "dir": "lpng1637",
        "build": [
            # lint: do not inline
            cmd_cmake(("-DPNG_SHARED:BOOL=OFF", "-DPNG_TESTS:BOOL=OFF")),
            cmd_nmake(target="clean"),
            cmd_nmake(),
            cmd_copy("libpng16_static.lib", "libpng16.lib"),
        ],
        "headers": [r"png*.h"],
        "libs": [r"libpng16.lib"],
    },
    "libavif": {
        "url": "https://github.com/AOMediaCodec/libavif/archive/v0.10.1.tar.gz",
        "filename": "libavif-0.10.1.tar.gz",
        "dir": "libavif-0.10.1",
        "build": [
            cmd_append("PATH", r"{program_files}\Meson"),
            cmd_cd("ext"),
            "@echo ::group::Building SVT-AV1",
            cmd_rmdir("SVT-AV1"),
            "cmd.exe /c svt.cmd",
            "@echo ::endgroup::",
            "@echo ::group::Building aom",
            cmd_rmdir("aom"),
            'cmd.exe /c "aom.cmd"',
            "@echo ::endgroup::",
            "@echo ::group::Building dav1d",
            cmd_rmdir("dav1d"),
            'cmd.exe /c "dav1d.cmd"',
            "@echo ::endgroup::",
            "@echo ::group::Building libavif",
            cmd_cd(".."),
            cmd_rmdir("build"),
            cmd_mkdir("build"),
            cmd_cd("build"),
            cmd_cmake(
                [
                    "-DBUILD_SHARED_LIBS=OFF",
                    "-DAVIF_CODEC_AOM=ON",
                    "-DAVIF_LOCAL_AOM=ON",
                    "-DAVIF_CODEC_DAV1D=ON",
                    "-DAVIF_LOCAL_DAV1D=ON",
                    "-DAVIF_CODEC_SVT=ON",
                    "-DAVIF_LOCAL_SVT=ON",
                ],
                "..",
            ),
            cmd_nmake(),
            cmd_cd(".."),
            cmd_lib_combine(
                r"avif.lib",
                r"build\avif.lib",
                r"ext\aom\build.libavif\aom.lib",
                r"ext\dav1d\build\src\libdav1d.a",
                r"ext\SVT-AV1\Bin\Release\SvtAv1Enc.lib",
            ),
            cmd_mkdir(r"{inc_dir}\avif"),
            cmd_copy(r"include\avif\avif.h", r"{inc_dir}\avif"),
            "@echo ::endgroup::"
        ],
        "libs": [r"*.lib"],
    },
}


# based on distutils._msvccompiler from CPython 3.7.4
def find_msvs():
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

    vs = {
        "header": [],
        # nmake selected by vcvarsall
        "nmake": "nmake.exe",
        "vs_dir": vspath,
    }

    # vs2017
    msbuild = os.path.join(vspath, "MSBuild", "15.0", "Bin", "MSBuild.exe")
    if os.path.isfile(msbuild):
        vs["msbuild"] = '"{msbuild}"'.format(msbuild=msbuild)
    else:
        # vs2019
        msbuild = os.path.join(vspath, "MSBuild", "Current", "Bin", "MSBuild.exe")
        if os.path.isfile(msbuild):
            vs["msbuild"] = '"{msbuild}"'.format(msbuild=msbuild)
        else:
            print("Visual Studio MSBuild not found")
            return None

    vcvarsall = os.path.join(vspath, "VC", "Auxiliary", "Build", "vcvarsall.bat")
    if not os.path.isfile(vcvarsall):
        print("Visual Studio vcvarsall not found")
        return None
    vs["header"].append('call "{vcvarsall}" {{vcvars_arch}}'.format(
        vcvarsall=vcvarsall
    ))

    return vs


def fetch(url, file):
    try:
        from urllib.request import urlopen
        from urllib.error import URLError
    except ImportError:
        from urllib2 import urlopen
        from urllib2 import URLError

    if not os.path.exists(file):
        ex = None
        for i in range(3):
            try:
                print("Fetching %s (attempt %d)..." % (url, i + 1))
                content = urlopen(url).read()
                with open(file, "wb") as f:
                    f.write(content)
                break
            except URLError as e:
                ex = e
        else:
            raise RuntimeError(ex)


def extract_dep(url, filename):
    import tarfile
    import zipfile

    file = os.path.join(depends_dir, filename)
    fetch(url, file)
    print("Extracting " + filename)
    if filename.endswith(".zip"):
        with zipfile.ZipFile(file) as zf:
            zf.extractall(sources_dir)
    elif filename.endswith(".tar.gz") or filename.endswith(".tgz"):
        with tarfile.open(file, "r:gz") as tgz:
            tgz.extractall(sources_dir)
    else:
        raise RuntimeError("Unknown archive type: " + filename)


def write_script(name, lines):
    name = os.path.join(build_dir, name)
    lines = [line.format(**prefs) for line in lines]
    print("Writing " + name)
    with open(name, "w") as f:
        f.write("\n\r".join(lines))
    if verbose:
        for line in lines:
            print("    " + line)


def get_footer(dep):
    lines = []
    for out in dep.get("headers", []):
        lines.append(cmd_copy(out, "{inc_dir}"))
    for out in dep.get("libs", []):
        lines.append(cmd_copy(out, "{lib_dir}"))
    for out in dep.get("bins", []):
        lines.append(cmd_copy(out, "{bin_dir}"))
    return lines


def build_dep(name):
    dep = deps[name]
    dir = dep["dir"]
    file = "build_dep_{name}.cmd".format(name=name)

    extract_dep(dep["url"], dep["filename"])

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
            f.write(text)

    banner = "Building {name} ({dir})".format(name=name, dir=dir)
    lines = [
        "@echo " + ("=" * 70),
        "@echo ==== {banner:<60} ====".format(banner=banner),
        "@echo " + ("=" * 70),
        "cd /D %s" % os.path.join(sources_dir, dir),
    ]
    lines += prefs["header"]
    lines += dep.get("build", [])
    lines += get_footer(dep)
    write_script(file, lines)
    return file


def build_dep_all():
    lines = ["@echo on"]
    for dep_name in deps:
        if dep_name in disabled:
            continue
        script = build_dep(dep_name)
        lines.append(r'cmd.exe /c "{{build_dir}}\{script}"'.format(
            build_dir=build_dir,
            script=script,
        ))
        lines.append("if errorlevel 1 echo Build failed! && exit /B 1")
    lines.append("@echo All pillow-avif-plugin dependencies built successfully!")
    write_script("build_dep_all.cmd", lines)


def install_pillow():
    lines = [
        "@echo on",
        "@echo ---- Installing pillow ----",
        r'"{python_dir}\{python_exe}" -m pip install Pillow',
        "@echo Pillow installed successfully",
    ]
    write_script("install_pillow.cmd", lines)


def install_meson():
    msi_url = "https://github.com/mesonbuild/meson/releases/download/0.56.2/meson-0.56.2-64.msi"  # noqa: E501
    msi_file = os.path.join(depends_dir, "meson-0.56.2-64.msi")
    fetch(msi_url, msi_file)

    lines = [
        "@echo on",
        "@echo ---- Installing meson ----",
        "msiexec /q /i %s" % msi_file,
        "@echo meson installed successfully",
    ]
    write_script("install_meson.cmd", lines)


def build_pillow_avif_plugin():
    lines = [
        "@echo ---- Building pillow-avif-plugin (build_ext %*) ----",
        cmd_cd("{pillow_avif_plugin_dir}"),
    ] + prefs["header"] + [
        cmd_set("DISTUTILS_USE_SDK", "1"),  # use same compiler to build pillow-avif
        cmd_set("MSSdk", "1"),  # for PyPy3.6
        cmd_set("py_vcruntime_redist", "true"),  # use /MD, not /MT
        r'"{python_dir}\{python_exe}" setup.py build_ext %*',
    ]

    write_script("build_pillow_avif_plugin.cmd", lines)


if __name__ == "__main__":
    # winbuild directory
    winbuild_dir = os.path.dirname(os.path.realpath(__file__))

    verbose = False
    disabled = []
    depends_dir = os.environ.get("PILLOW_DEPS", os.path.join(winbuild_dir, "depends"))
    python_dir = os.environ.get("PYTHON")
    python_exe = os.environ.get("EXECUTABLE", "python.exe")
    architecture = os.environ.get(
        "ARCHITECTURE", "x86" if struct.calcsize("P") == 4 else "x64"
    )
    build_dir = os.environ.get("PILLOW_BUILD", os.path.join(winbuild_dir, "build"))
    sources_dir = ""
    for arg in sys.argv[1:]:
        if arg == "-v":
            verbose = True
        elif arg.startswith("--depends="):
            depends_dir = arg[10:]
        elif arg.startswith("--python="):
            python_dir = arg[9:]
        elif arg.startswith("--executable="):
            python_exe = arg[13:]
        elif arg.startswith("--architecture="):
            architecture = arg[15:]
        elif arg.startswith("--dir="):
            build_dir = arg[6:]
        elif arg == "--srcdir":
            sources_dir = os.path.sep + "src"
        else:
            raise ValueError("Unknown parameter: " + arg)

    # dependency cache directory
    if not os.path.exists(depends_dir):
        os.makedirs(depends_dir)
    print("Caching dependencies in:", depends_dir)

    if python_dir is None:
        python_dir = os.path.dirname(os.path.realpath(sys.executable))
        python_exe = os.path.basename(sys.executable)
    print("Target Python:", os.path.join(python_dir, python_exe))

    arch_prefs = architectures[architecture]
    print("Target Architecture:", architecture)

    msvs = find_msvs()
    if msvs is None:
        raise RuntimeError(
            "Visual Studio not found. Please install Visual Studio 2017 or newer."
        )
    print("Found Visual Studio at:", msvs["vs_dir"])

    print("Using output directory:", build_dir)

    # build directory for *.h files
    inc_dir = os.path.join(build_dir, "inc")
    # build directory for *.lib files
    lib_dir = os.path.join(build_dir, "lib")
    # build directory for *.bin files
    bin_dir = os.path.join(build_dir, "bin")
    # directory for storing project files
    sources_dir = build_dir + sources_dir

    shutil.rmtree(build_dir, ignore_errors=True)
    if not os.path.exists(build_dir):
        os.makedirs(build_dir)
    for path in [inc_dir, lib_dir, bin_dir, sources_dir]:
        if not os.path.exists(path):
            os.makedirs(path)

    prefs = {
        # Python paths / preferences
        "python_dir": python_dir,
        "python_exe": python_exe,
        "architecture": architecture,
        # Pillow paths
        "pillow_avif_plugin_dir": os.path.realpath(os.path.join(winbuild_dir, "..")),
        "winbuild_dir": winbuild_dir,
        # Build paths
        "build_dir": build_dir,
        "inc_dir": inc_dir,
        "lib_dir": lib_dir,
        "bin_dir": bin_dir,
        "src_dir": sources_dir,
        "program_files": os.environ["ProgramFiles"],
        # Compilers / Tools
        "cmake": "cmake.exe",  # TODO find CMAKE automatically
        # TODO find NASM automatically
    }
    prefs.update(arch_prefs)
    prefs.update(msvs)

    # script header
    prefs["header"] = sum([header, msvs["header"], ["@echo on"]], [])

    for k, v in deps.items():
        prefs["dir_%s" % k] = os.path.join(sources_dir, v["dir"])

    print()

    write_script(".gitignore", ["*"])
    build_dep_all()
    install_pillow()
    install_meson()
    build_pillow_avif_plugin()
