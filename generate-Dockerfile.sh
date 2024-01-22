#!/usr/bin/env bash
cd $(cd -P -- "$(dirname -- "$0")" && pwd -P)

# Set the path of the generated Dockerfile
export DOCKERFILE=".build/Dockerfile"
export STACKS_DIR=".build/docker-stacks"
# please test the build of the commit in https://github.com/jupyter/docker-stacks/commits/main in advance
export HEAD_COMMIT="1494233e27cdc70e3766ea2518e7153ee425fc4f"

while [[ "$#" -gt 0 ]]; do case $1 in
  -p|--pw|--password) PASSWORD="$2" && USE_PASSWORD=1; shift;;
  -c|--commit) HEAD_COMMIT="$2"; shift;;
  --no-datascience-notebook) no_datascience_notebook=1;;
  --python-only) no_datascience_notebook=1;;
  --no-useful-packages) no_useful_packages=1;;
  -s|--slim) no_datascience_notebook=1 && no_useful_packages=1;;
  -h|--help) HELP=1;;
  *) echo "Unknown parameter passed: $1" && HELP=1;;
esac; shift; done

if [[ "$HELP" == 1 ]]; then
    echo "Help for ./generate-Dockerfile.sh:"
    echo "Usage: $0 [parameters]"
    echo "    -h|--help: Show this help."
    echo "    -p|--pw|--password: Set the password (creates .build/jupyter_notebook_config.json and overrides the token)"
    echo "    -c|--commit: Set the head commit of the jupyter/docker-stacks submodule (https://github.com/jupyter/docker-stacks/commits/main). default: $HEAD_COMMIT."
    echo "    --python-only|--no-datascience-notebook: Use not the datascience-notebook from jupyter/docker-stacks, don't install Julia and R."
    echo "    --no-useful-packages: Don't install the useful packages, specified in custom/usefulpackages.Dockerfile"
    echo "    --slim: no useful packages and no datascience notebook."
    exit 21
fi

# Clone if docker-stacks doesn't exist, and set to the given commit or the default commit
ls $STACKS_DIR/README.md  > /dev/null 2>&1  || (echo "Docker-stacks was not found, cloning repository" \
 && git clone https://github.com/jupyter/docker-stacks.git $STACKS_DIR)
echo "Set docker-stacks to commit '$HEAD_COMMIT'."
if [[ "$HEAD_COMMIT" == "latest" ]]; then
  echo "WARNING, the latest commit of docker-stacks is used. This may result in version conflicts"
  cd $STACKS_DIR && git pull && cd -
else
  export GOT_HEAD="false"
  cd $STACKS_DIR && git pull && git reset --hard "$HEAD_COMMIT" > /dev/null 2>&1  && cd - && export GOT_HEAD="true"
  echo "$HEAD"
  if [[ "$GOT_HEAD" == "false" ]]; then
    echo "Error: The provided sha-commit is invalid."
    echo "Usage: $0 -c [sha-commit] # set the head commit of the docker-stacks submodule (https://github.com/jupyter/docker-stacks/commits/master)."
    echo "Exiting"
    exit 2
  else
    echo "Set head to given commit."
  fi
fi

# Write the contents into the DOCKERFILE and start with the header
echo "# This Dockerfile is generated by 'generate-Dockerfile.sh' from elements within 'custom/'

# **Please do not change this file directly!**
# To adapt this Dockerfile, adapt 'generate-Dockerfile.sh' or 'custom/usefulpackages.Dockerfile'.
# More information can be found in the README under configuration.

" > $DOCKERFILE
cat custom/header.Dockerfile >> $DOCKERFILE

echo "
############################################################################
#################### Dependency: jupyter/docker-stacks-foundation ##########
############################################################################
" >> $DOCKERFILE
if [ -f "$STACKS_DIR/images/docker-stacks-foundation/Dockerfile" ]; then
    cat $STACKS_DIR/images/docker-stacks-foundation/Dockerfile | grep -v 'BASE_CONTAINER' | grep -v 'FROM $ROOT_CONTAINER' >> $DOCKERFILE
    # copy files that are used during the build
    cp $STACKS_DIR/images/docker-stacks-foundation/initial-condarc .build/
    cp $STACKS_DIR/images/docker-stacks-foundation/fix-permissions .build/
    cp $STACKS_DIR/images/docker-stacks-foundation/start.sh .build/
    cp $STACKS_DIR/images/docker-stacks-foundation/run-hooks.sh .build/
    cp $STACKS_DIR/images/docker-stacks-foundation/10activate-conda-env.sh .build/
else
    cat $STACKS_DIR/docker-stacks-foundation/Dockerfile | grep -v 'BASE_CONTAINER' | grep -v 'FROM $ROOT_CONTAINER' >> $DOCKERFILE
    # copy files that are used during the build
    cp $STACKS_DIR/docker-stacks-foundation/initial-condarc .build/
    cp $STACKS_DIR/docker-stacks-foundation/fix-permissions .build/
    cp $STACKS_DIR/docker-stacks-foundation/start.sh .build/
fi

echo "
############################################################################
#################### Dependency: jupyter/base-notebook #####################
############################################################################
" >> $DOCKERFILE
if [ -f "$STACKS_DIR/images/base-notebook/Dockerfile" ]; then
    cat $STACKS_DIR/images/base-notebook/Dockerfile | grep -v 'BASE_CONTAINER' >> $DOCKERFILE
    # copy files that are used during the build
    cp $STACKS_DIR/images/base-notebook/jupyter_server_config.py .build/
    cp $STACKS_DIR/images/base-notebook/start-notebook.sh .build/
    cp $STACKS_DIR/images/base-notebook/start-notebook.py .build/
    cp $STACKS_DIR/images/base-notebook/start-singleuser.sh .build/
    cp $STACKS_DIR/images/base-notebook/start-singleuser.py .build/
    cp $STACKS_DIR/images/base-notebook/docker_healthcheck.py .build/
else
    cat $STACKS_DIR/base-notebook/Dockerfile | grep -v 'BASE_CONTAINER' >> $DOCKERFILE
    # copy files that are used during the build
    cp $STACKS_DIR/base-notebook/jupyter_server_config.py .build/
    cp $STACKS_DIR/base-notebook/start-notebook.sh .build/
    cp $STACKS_DIR/base-notebook/start-singleuser.sh .build/
    cp $STACKS_DIR/base-notebook/docker_healthcheck.py .build/
fi
chmod 755 .build/*

echo "
############################################################################
################# Dependency: jupyter/minimal-notebook #####################
############################################################################
" >> $DOCKERFILE
if [ -f "$STACKS_DIR/images/minimal-notebook/Dockerfile" ]; then
    cat $STACKS_DIR/images/minimal-notebook/Dockerfile | grep -v BASE_CONTAINER >> $DOCKERFILE
    # copy files that are used during the build
    cp -r $STACKS_DIR/images/minimal-notebook/setup-scripts .build/
    cp $STACKS_DIR/images/minimal-notebook/Rprofile.site .build/
else
    cat $STACKS_DIR/minimal-notebook/Dockerfile | grep -v BASE_CONTAINER >> $DOCKERFILE
    # copy files that are used during the build
    cp -r $STACKS_DIR/minimal-notebook/setup-scripts .build/
    cp $STACKS_DIR/minimal-notebook/Rprofile.site .build/
fi

echo "
############################################################################
################# Dependency: jupyter/scipy-notebook #######################
############################################################################
" >> $DOCKERFILE
if [ -f "$STACKS_DIR/images/scipy-notebook/Dockerfile" ]; then
    cat $STACKS_DIR/images/scipy-notebook/Dockerfile | grep -v BASE_CONTAINER >> $DOCKERFILE
else
    cat $STACKS_DIR/scipy-notebook/Dockerfile | grep -v BASE_CONTAINER >> $DOCKERFILE
fi

# install Julia and R if not excluded or spare mode is used
if [[ "$no_datascience_notebook" != 1 ]]; then
  echo "
  ############################################################################
  ################ Dependency: jupyter/datascience-notebook ##################
  ############################################################################
  " >> $DOCKERFILE
    if [ -f "$STACKS_DIR/images/datascience-notebook/Dockerfile" ]; then
        cat $STACKS_DIR/images/datascience-notebook/Dockerfile | grep -v BASE_CONTAINER >> $DOCKERFILE
    else
        cat $STACKS_DIR/images/datascience-notebook/Dockerfile | grep -v BASE_CONTAINER >> $DOCKERFILE
    fi
else
  echo "Set 'no-datascience-notebook' = 'python-only', not installing the datascience-notebook with Julia and R."
fi

# Note that the following step also installs the cudatoolkit, which is
# essential to access the GPU.
echo "
############################################################################
########################## Dependency: gpulibs #############################
############################################################################
" >> $DOCKERFILE
cat custom/gpulibs.Dockerfile >> $DOCKERFILE

# install useful packages if not excluded or spare mode is used
if [[ "$no_useful_packages" != 1 ]]; then
  echo "
  ############################################################################
  ############################ Useful packages ###############################
  ############################################################################
  " >> $DOCKERFILE
  cat custom/usefulpackages.Dockerfile >> $DOCKERFILE
else
  echo "Set 'no-useful-packages', not installing stuff within custom/usefulpackages.Dockerfile."
fi

# Copy the demo notebooks and change permissions
cp -r extra/Getting_Started data
chmod -R 755 data/

# set static token
# copy jupyter server config token addendum to .build
cp custom/jupyter_server_config_token_addendum.py .build/
# append token config into the jupyter server config
echo >> $DOCKERFILE
echo "# Set env-var JUPYTER_TOKEN as static token" >> $DOCKERFILE
echo "ARG JUPYTER_TOKEN"  >> $DOCKERFILE
echo "ENV JUPYTER_TOKEN=\$JUPYTER_TOKEN"  >> $DOCKERFILE
echo "COPY jupyter_server_config_token_addendum.py /etc/jupyter/" >> $DOCKERFILE
echo "RUN cat /etc/jupyter/jupyter_server_config_token_addendum.py >> /etc/jupyter/jupyter_server_config.py" >> $DOCKERFILE


# set password
if [[ "$USE_PASSWORD" == 1 ]]; then
  echo "Set password to given input"
  SALT="3b4b6378355"
  HASHED=$(echo -n ${PASSWORD}${SALT} | sha1sum | awk '{print $1}')
  unset PASSWORD  # delete variable PASSWORD
  # build jupyter_notebook_config.json
  echo "{
  \"NotebookApp\": {
    \"password\": \"sha1:$SALT:$HASHED\"
  }
}" > .build/jupyter_notebook_config.json

  # copy the config into .build and append the lines into the Dockerfile
  echo >> $DOCKERFILE
  echo "# Copy jupyter_notebook_config.json" >> $DOCKERFILE
  echo "COPY jupyter_notebook_config.json /etc/jupyter/"  >> $DOCKERFILE
fi

# Set environment variables
export JUPYTER_UID=$(id -u)
export JUPYTER_GID=$(id -g)

#cp $(find $(dirname $DOCKERFILE) -type f | grep -v $STACKS_DIR | grep -v .gitkeep) .
echo
echo "The GPU Dockerfile was generated successfully in file ${DOCKERFILE}."
echo "To start the GPU-based Juyterlab instance, run:"
echo "  docker build -t gpu-jupyter .build/  # will take a while"
echo "  docker run --gpus all -d -it -p 8848:8888 -v $(pwd)/data:/home/jovyan/work -e GRANT_SUDO=yes -e JUPYTER_ENABLE_LAB=yes -e NB_UID=$(id -u) -e NB_GID=$(id -g) --user root --restart always --name gpu-jupyter_1 gpu-jupyter"
