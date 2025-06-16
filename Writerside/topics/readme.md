# About OOD Neurodocker
OOD Neurodocker is a tool for creating Docker images for OpenOnDemand. 
It was initially designed by the ReproNim repository to create Docker images for neuroimaging software.

However the concept has been very useful to create any Docker image for OpenOnDemand.

# Getting started
## Short version:
Read generate_apps.sh
source generate_apps.sh
Call a function to generate a Docker image for OpenOnDemand

## Functional version:
1. Clone the repository into your RubyMine IDE
1. Create a Python virtual environment (slightly optional but recommended):
   - `python3 -m venv .venv`
   - `source .venv/bin/activate` (Linux/Mac) or `.venv\Scripts\activate` (Windows)
1. Install the dependencies:
   - `pip install -r requirements.txt`
1. Make sure Neurodocker and YQ are installed and in your PATH:
   - `neurodocker --version`
   - `yq --version`
1. Set the environment variable to generate a Docker image for OpenOnDemand:
   - `export CONTAINER=docker`
1. Source the script to generate the Docker image:
   - `source generate_apps.sh`
1. Build the Docker image:
   - `build_doom`
1. IF that works, you can now edit generate_apps.sh to add more applications or modify the existing ones.
1. Read the neurodocker documentation to understand how to use templates which are in nd_templates/
1. Go back to source the script if you make changes to generate_apps.sh

# Testing the generated Docker image
If you build the container with Docker, you should see "naming to docker.io/library/your_software:version" in the output
and the image will be available locally.

You can test the generated Docker image by running the following command (eg. for KasmVnc):
```bash
export XVNC_OPTIONS="-websocketPort 8080 -disableBasicAuth"
docker run --rm -it -p 8080:8080 \
  -e XVNC_OPTIONS \
  -v ~/test_home:/home/nonroot \
  --name kasmvnc \
  --entrypoint /bin/bash \
  your_software:version
```
Note this runs the /bin/bash entrypoint, so you can test the image interactively.
Once inside the container, you can run the command to start the application, e.g.:
```bash
/opt/kasm_startup.sh
```

# Making more images
Copy/paste from another app, modify the various variables to your liking
The way it works is that it will rsync in order:
- the template directory
- the appname_template directory
- the appname_gui_template directory if it has both a gui and a terminal option

There are various templates you can include in your neurodocker generate command
They will basically be parsed in order and added to the Dockerfile and/or Singularity container document

This MAY be slightly inefficient at build time but the composability is worth it.

# Documentation:
Using WriterSide.

# TODO:
- Add a cleanup template that minifies the container
- Add RPM builds for common tools
- Compile this documentation to a static page for both GitLab and GitHub