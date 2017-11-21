#!/bin/bash
echo "Docker runtime - BEGIN"

echo "Docker runtime - Will get wheel from S3 (i.e. not local wheel)"
# wheel=${encodedFullVersionTag}${extratag}/h2o4gpu-${encodedFullVersionTag}-py36-none-any.whl # use this if want to pull from s3 in Dockerfile-runtime
nvidia-docker build -t opsh2oai/h2o4gpu-${versionTag}${extratag}-runtime:latest -f Dockerfile-runtime --rm=false --build-arg cuda=${dockerimage} .
# -u `id -u`:`id -g` -d -t -w `pwd` -v `pwd`:`pwd`:rw

echo "Runtime Docker - Run"
nvidia-docker run --init --rm --name ${CONTAINER_NAME} -d -t -u root -v /home/0xdiag/h2o4gpu/data:/data -v /home/0xdiag/h2o4gpu/open_data:/open_data -v `pwd`:/dot  --entrypoint=bash opsh2oai/h2o4gpu-${versionTag}${extratag}-runtime:latest

echo "Docker runtime - pip install h2o4gpu and pip freeze"
nvidia-docker exec ${CONTAINER_NAME} bash -c '. /h2o4gpu_env/bin/activate ; pip install `find /dot/src/interface_py/'${dist}' -name "*h2o4gpu-*.whl"` ; pip freeze'

echo "Docker runtime - Getting Data"
nvidia-docker exec ${CONTAINER_NAME} bash -c '. /h2o4gpu_env/bin/activate ; mkdir -p scripts ; rm -rf scripts/fcov_get.py ; echo "from sklearn.datasets import fetch_covtype" > ./scripts/fcov_get.py ; echo "cov = fetch_covtype()" >> ./scripts/fcov_get.py'
nvidia-docker exec ${CONTAINER_NAME} bash -c '. /h2o4gpu_env/bin/activate ; cd /jupyter/ ; python ../scripts/fcov_get.py'
nvidia-docker exec ${CONTAINER_NAME} bash -c 'cd /jupyter/demos ; cp /data/creditcard.csv .'
nvidia-docker exec ${CONTAINER_NAME} bash -c 'cd /jupyter/demos ; wget https://s3.amazonaws.com/h2o-public-test-data/h2o4gpu/open_data/kmeans_data/h2o-logo.jpg'
nvidia-docker exec ${CONTAINER_NAME} bash -c 'cd /jupyter/demos ; cp /data/ipums_1k.csv .'
nvidia-docker exec ${CONTAINER_NAME} bash -c 'cd /jupyter/demos ; cp /data/ipums.feather .'
nvidia-docker commit ${CONTAINER_NAME} opsh2oai/h2o4gpu-${versionTag}${extratag}-runtime:latest

echo "Docker runtime - stopping docker"
nvidia-docker stop ${CONTAINER_NAME}

echo "Docker runtime - saving docker to local disk"
nvidia-docker save opsh2oai/h2o4gpu-${versionTag}${extratag}-runtime | gzip > h2o4gpu-${fullVersionTag}${extratag}-runtime.tar.gz

echo "Docker runtime - END"
