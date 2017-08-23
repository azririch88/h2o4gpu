#!/usr/bin/groovy
// TOOD: rename to @Library('h2o-jenkins-pipeline-lib') _
@Library('test-shared-library') _

import ai.h2o.ci.Utils

def utilsLib = new Utils()

pipeline {
    agent none

    // Setup job options
    options {
        ansiColor('xterm')
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '10'))
        disableConcurrentBuilds()
    }

    environment {
        MAKE_OPTS = "-s CI=1" // -s: silent mode
    }

    stages {

        stage('Build on Linux') {
            agent {
                label "mr-dl11"
            }
            steps {
                dumpInfo 'Linux Build Info'
                checkout([
                        $class                           : 'GitSCM',
                        branches                         : scm.branches,
                        doGenerateSubmoduleConfigurations: false,
                        extensions                       : scm.extensions + [[$class: 'SubmoduleOption', disableSubmodules: false, recursiveSubmodules: true, reference: '', trackingSubmodules: false]],
                        submoduleCfg                     : [],
                        userRemoteConfigs                : scm.userRemoteConfigs])

                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: "awsArtifactsUploader"]]) {
                    sh """
                    nvidia-docker build -t opsh2oai/h2o4gpu-build -f Dockerfile-build .
                    nvidia-docker run --rm --name h2o4gpu-$BUILD_ID -d -t -u `id -u`:`id -g` -v /home/0xdiag/h2ogpuml/data:/data -w `pwd` -v `pwd`:`pwd`:rw --entrypoint=bash opsh2oai/h2o4gpu-build
                    nvidia-docker exec h2o4gpu-$BUILD_ID rm -rf data
                    nvidia-docker exec h2o4gpu-$BUILD_ID ln -s /data ./data
                    nvidia-docker exec h2o4gpu-$BUILD_ID bash -c '. /h2oai_env/bin/activate; make ${env.MAKE_OPTS} AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} fullinstalljenkins'
                    nvidia-docker stop h2o4gpu-$BUILD_ID
                        """
                    stash includes: 'src/interface_py/dist/*.whl', name: 'linux_whl'
                    // Archive artifacts
                    arch 'src/interface_py/dist/*.whl'
                }
            }
        }
        stage('Test on Linux') {
            agent {
                label "mr-dl11"
            }
            steps {
                unstash 'linux_whl'
                dumpInfo 'Linux Test Info'
                script {
                    try {
                        sh """
                            nvidia-docker run --rm --name h2o4gpu-$BUILD_ID -d -t -u `id -u`:`id -g` -v /home/0xdiag/h2ogpuml/data:/data -w `pwd` -v `pwd`:`pwd`:rw --entrypoint=bash opsh2oai/h2o4gpu-build
                            nvidia-docker exec h2o4gpu-$BUILD_ID rm -rf py3nvml
                            nvidia-docker exec h2o4gpu-$BUILD_ID bash -c '. /h2oai_env/bin/activate; pip install `find src/interface_py/dist -name "*h2ogpuml*.whl"`; make dotest'
                        """
                    } finally {
                        sh """
                            nvidia-docker stop h2o4gpu-$BUILD_ID
                        """
                        arch 'tmp/*.log'
                        junit testResults: 'build/test-reports/*.xml', keepLongStdio: true, allowEmptyResults: false
                        deleteDir()
                    }
                }
            }
        }

        // Publish into S3 all snapshots versions
        stage('Publish snapshot to S3') {
            when {
                branch 'master'
            }
            agent {
                label "linux"
            }
            steps {
                unstash 'linux_whl'
                sh 'echo "Stashed files:" && ls -l src/interface_py/dist/'
                script {
                    s3up {
                        localArtifact = 'src/interface_py/dist/*h2ogpuml*.whl'
                        artifactId = "h2o4gpu"
                        majorVersion = 0
                        buildVersion = 3
                    }
                }
            }
        }

    }
}
