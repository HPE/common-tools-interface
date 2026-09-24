# Copyright 2022 Hewlett Packard Enterprise Debelopment LP
#
# Install necessary libraries for the test too to run

import os, sys, subprocess

# copied from cdst_test.useful to avoid having to import anything for the bootstrap
def successful_launch(launch_array, quiet = False):
    print("Running " + " ".join(launch_array))
    p = subprocess.run(launch_array, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return p.returncode == 0

def bootstrap():
    # install local python
    if not os.path.exists(os.environ["HOME"] + "/.local/bin/pip3"):
        print("Installing pip...")

        vers_major, vers_minor, _, _, _ = sys.version_info

        bootstrap_url = ""
        if vers_major == 3 and vers_minor >= 7:
            bootstrap_url = "https://bootstrap.pypa.io/get-pip.py"
        elif vers_major == 3 and vers_minor <= 6:
            # python 3.6 and under has a different url
            bootstrap_url = f"https://bootstrap.pypa.io/pip/3.{vers_minor}/get-pip.py"
        else:
            print(f"Unsupported python version: {vers_major}.{vers_minor}")
            return False

        print(f"Getting pip from {bootstrap_url}")
        if not successful_launch(["curl", bootstrap_url, "-o", "get-pip.py"], quiet=True):
            print("Failed to download pip setup script.")
            return False

        if not successful_launch(["python3", "get-pip.py", "--user"], quiet=True):
            print("Failed to run pip installer.")
            return False

        os.remove("./get-pip.py")

    # install virtualenv
    if not successful_launch(["python3", "-m", "virtualenv", "--version"], quiet=True):
        print("Installing virtualenv...")
        if os.path.isfile(f"{os.environ['HOME']}/.local/bin/pip3"):
            if not successful_launch([os.environ["HOME"] + "/.local/bin/pip3", "install", "--user", "virtualenv"], quiet=True):
                print("Failed to install virtual environment python module.")
                return False
        else:
            print(f"Failed to install virtual environment module: no pip3 in {os.environ['HOME']}/.local/bin")
            return False

    # install other required libraries
    print("Installing additional libraries...")
    if not successful_launch(["python3", "-m", "pip", "install", "-r", os.path.dirname(os.path.abspath(__file__)) + "/requirements.txt"], quiet=True):
        print("Failed to install libraries.")
        return False

    return True

if __name__ == "__main__":
    exit(0 if bootstrap() else -1)

