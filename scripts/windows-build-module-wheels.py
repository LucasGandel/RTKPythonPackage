from subprocess import check_call
import os
import sys

SCRIPT_DIR = os.path.dirname(__file__)
ROOT_DIR = os.path.abspath(os.getcwd())


print("SCRIPT_DIR: %s" % SCRIPT_DIR)
print("ROOT_DIR: %s" % ROOT_DIR)

from wheel_builder_utils import push_dir, push_env
# from windows_build_common import DEFAULT_PY_ENVS, venv_paths

DEFAULT_PY_ENVS = ["35-x64", "36-x64", "37-x64"]

def venv_paths(python_version):

    # Create venv
    venv_executable = "C:/Python%s/Scripts/virtualenv.exe" % (python_version)
    venv_dir = os.path.join(ROOT_DIR, "venv-%s" % python_version)
    check_call([venv_executable, venv_dir])

    python_executable = os.path.join(venv_dir, "Scripts", "python.exe")
    python_include_dir = os.path.join(venv_dir, "Include")

    # XXX It should be possible to query skbuild for the library dir associated
    #     with a given interpreter.
    xy_ver = python_version.split("-")[0]

    python_library = "C:/Python%s/libs/python%s.lib" % (python_version, xy_ver)

    print("")
    print("PYTHON_EXECUTABLE: %s" % python_executable)
    print("PYTHON_INCLUDE_DIR: %s" % python_include_dir)
    print("PYTHON_LIBRARY: %s" % python_library)

    pip = os.path.join(venv_dir, "Scripts", "pip.exe")

    ninja_executable = os.path.join(venv_dir, "Scripts", "ninja.exe")
    print("NINJA_EXECUTABLE:%s" % ninja_executable)

    # Update PATH
    path = os.path.join(venv_dir, "Scripts")

    return python_executable, \
        python_include_dir, \
        python_library, \
        pip, \
        ninja_executable, \
        path

def build_wheels(py_envs=DEFAULT_PY_ENVS):
    for py_env in py_envs:
        python_executable, \
                python_include_dir, \
                python_library, \
                pip, \
                ninja_executable, \
                path = venv_paths(py_env)

        with push_env(PATH="%s%s%s" % (path, os.pathsep, os.environ["PATH"])):

            # Install dependencies
            requirements_file = os.path.join(ROOT_DIR, "requirements-dev.txt")
            if os.path.exists(requirements_file):
                check_call([pip, "install", "--upgrade", "-r", requirements_file])
            check_call([pip, "install", "cmake"])
            check_call([pip, "install", "scikit_build"])
            check_call([pip, "install", "ninja"])

            build_type = "Release"
            source_path = ROOT_DIR
            itk_build_path = os.path.abspath("%s/ITK-win_%s" % ("C:/P/IPP/", py_env))
            print('ITKDIR: %s' % itk_build_path)

            # Generate wheel
            check_call([
                python_executable,
                "setup.py", "bdist_wheel",
                "--build-type", build_type, "-G", "Ninja",
                "--",
                "-DCMAKE_MAKE_PROGRAM:FILEPATH=%s" % ninja_executable,
                "-DITK_DIR:PATH=%s" % itk_build_path,
                "-DWRAP_ITK_INSTALL_COMPONENT_IDENTIFIER:STRING=PythonWheel",
                "-DSWIG_EXECUTABLE:FILEPATH=%s/Wrapping/Generators/SwigInterface/swig/bin/swig.exe" % itk_build_path,
                "-DBUILD_TESTING:BOOL=OFF",
                "-DRTK_BUILD_APPLICATIONS:BOOL=OFF",
                "-DRTK_USE_CUDA:BOOL=OFF",
                "-DPYTHON_EXECUTABLE:FILEPATH=%s" % python_executable,
                "-DPYTHON_INCLUDE_DIR:PATH=%s" % python_include_dir,
                "-DPYTHON_LIBRARY:FILEPATH=%s" % python_library
            ])
            # Cleanup
            check_call([python_executable, "setup.py", "clean"])

if __name__ == '__main__':
    build_wheels()