#!/bin/env python3

import os
import time
import uuid
from pathlib import Path

import docker
import pytest
from flaky import flaky

# Move to the repo root directory. We need to ADD home/ but we can only do that if
# home is a relative/not absolute path.
os.chdir(Path(__file__).parent.parent)

LATEST_SUPPORTED_UBUNTU = "ubuntu:22.04"

SUPPORTED_OS_IMAGES = (
    LATEST_SUPPORTED_UBUNTU,
    "ubuntu:20.04",
    "registry.access.redhat.com/ubi7/ubi",
    "mcr.microsoft.com/cbl-mariner/base/core:2.0",
)


@pytest.fixture(scope="session")
def docker_obj() -> docker.DockerClient:
    yield docker.from_env()


@pytest.fixture(scope="session")
def image(request, docker_obj: docker.DockerClient):
    orig_image = getattr(request, "param", LATEST_SUPPORTED_UBUNTU)

    dockerfile_text = f"""
        FROM  {orig_image}

        # https://serverfault.com/questions/949991/how-to-install-tzdata-on-a-ubuntu-docker-image
        ARG DEBIAN_FRONTEND=noninteractive
        ENV TZ=Etc/UTC

        ADD "./testing" "/testing"
        ADD "./home" "/home/csm10495"
        RUN chmod +x /testing/container_setup.sh
        RUN /testing/container_setup.sh
        WORKDIR /home/csm10495
        USER csm10495
        ENV CSM_ALWAYS_FOREGROUND="1"
        RUN bash -c "source /home/csm10495/.bashrc"
        ENV CSM_ALWAYS_FOREGROUND=""
        CMD sleep 999999
    """

    dockerfile = Path("Dockerfile" + str(uuid.uuid4()))
    dockerfile.write_text(dockerfile_text)
    build_log = []
    try:
        updated_image, build_log = docker_obj.images.build(
            path=os.getcwd(), rm=False, dockerfile=str(dockerfile)
        )
    except docker.errors.BuildError as e:
        build_log = e.build_log
        raise
    finally:
        for line in build_log:
            if "stream" in line:
                print(line["stream"], end="")
        dockerfile.unlink()

    yield updated_image


@pytest.fixture(
    scope="function", ids=lambda x: "allow_networking" if x else "no_networking"
)
def allow_networking(request):
    return getattr(request, "param", True)


@pytest.fixture(scope="function")
def container(
    request,
    image: docker.client.ImageCollection,
    docker_obj: docker.DockerClient,
    allow_networking: bool,
):
    container = docker_obj.containers.run(
        image,
        "sleep 999999",
        detach=True,
        tty=True,
        user="csm10495",
        group_add=["csm10495group"],
        remove=True,
        network_mode="host" if allow_networking else "none",
    )

    try:
        yield container
    finally:
        _, output = container.exec_run(
            'bash -c "if test -f /home/csm10495/.local/var/log/dotfiles/log.txt; then cat /home/csm10495/.local/var/log/dotfiles/log.txt; fi"'
        )
        print("Log file contents:")
        print(output.decode("utf-8") or "<empty>")

        # will remove since remove=True
        container.kill()


try_with_and_without_networking = pytest.mark.parametrize(
    "allow_networking",
    [True, False],
    indirect=True,
    ids=lambda x: "networking" if x else "no_networking",
)


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
@try_with_and_without_networking
def test_simple_pwd(container, image):
    exit_code, output = container.exec_run("pwd")
    assert exit_code == 0
    assert output.strip() == b"/home/csm10495"


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
@try_with_and_without_networking
def test_source_no_errors(container, image):
    exit_code, output = container.exec_run('bash -c "source ~/.bashrc"')
    assert exit_code == 0
    assert output.strip() == b""


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
def test_has_nano(container, image):
    exit_code, _ = container.exec_run(
        'bash -c "source /home/csm10495/.bashrc && command -v nano"'
    )
    assert exit_code == 0


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
def test_has_kyrat(container, image):
    exit_code, _ = container.exec_run(
        'bash -c "source /home/csm10495/.bashrc && command -v kyrat"'
    )
    assert exit_code == 0


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
def test_has_ssh_to_kyrat(container, image):
    exit_code, output = container.exec_run(
        'bash -c "source /home/csm10495/.bashrc && ssh"'
    )
    assert exit_code != 0
    assert b"kyrat" in output


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
@flaky(max_runs=100, rerun_filter=lambda *args: time.sleep(2) or True)
def test_update_works(container, image):
    """This test is flaky in case we get throttled by the github api"""
    exit_code, output = container.exec_run(
        'bash -c "source /home/csm10495/.bashrc && _update_dotfiles"'
    )
    assert exit_code == 0
    assert output == b""

    exit_code, output = container.exec_run(
        'bash -c "source /home/csm10495/.bashrc && echo $CSM_BASHRC_VERSION && echo $CSM_BASHRC_HASH"'
    )
    assert exit_code == 0
    assert b"REPLACE_WITH_REPO_HASH" not in output
    assert b"REPLACE_WITH_VERSION" not in output


@pytest.mark.parametrize("image", SUPPORTED_OS_IMAGES, indirect=True)
def test_log_chomping(container, image):
    exit_code, _ = container.exec_run(
        """
        bash -c "source /home/csm10495/.bashrc &&
                for i in $(seq 1 10100); do
                    _csm_log $i
                done
        "
    """
    )
    assert exit_code == 0

    exit_code, output = container.exec_run(
        """
        bash -c "source /home/csm10495/.bashrc && cat /home/csm10495/.local/var/log/dotfiles/log.txt | wc -l"
    """
    )
    assert exit_code == 0

    # Its not actually 10000 since we chomp then log later in startup.
    assert int(output.strip()) < 10010
