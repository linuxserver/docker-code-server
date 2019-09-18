pipeline {
  agent {
    label 'X86-64-MULTI'
  }
  // Input to determine if this is a package check
  parameters {
     string(defaultValue: 'false', description: 'package check run', name: 'PACKAGE_CHECK')
  }
  // Configuration for the variables used for this specific repo
  environment {
    BUILDS_DISCORD=credentials('build_webhook_url')
    GITHUB_TOKEN=credentials('498b4638-2d02-4ce5-832d-8a57d01d97ab')
    JSON_URL = 'https://api.github.com/repos/cdr/code-server/releases'
    JSON_PATH = 'first(.[] | select(.prerelease == true)) | .tag_name'
    CONTAINER_NAME = 'code-server'
    BUILD_VERSION_ARG = 'CODE_RELEASE'
    LS_USER = 'linuxserver'
    LS_REPO = 'docker-code-server'
    DOCKERHUB_IMAGE = 'linuxserver/code-server'
    DEV_DOCKERHUB_IMAGE = 'lsiodev/code-server'
    PR_DOCKERHUB_IMAGE = 'lspipepr/code-server'
    DIST_IMAGE = 'ubuntu'
    MULTIARCH='false'
    CI='true'
    CI_WEB='true'
    CI_PORT='8443'
    CI_SSL='false'
    CI_DELAY='120'
    CI_DOCKERENV='TZ=US/Pacific'
    CI_AUTH='user:password'
    CI_WEBPATH=''
  }
  stages {
    // Setup all the basic environment variables needed for the build
    stage("Set ENV Variables base"){
      steps{
        script{
          env.EXIT_STATUS = ''
          env.LS_RELEASE = sh(
            script: '''docker run --rm alexeiled/skopeo sh -c 'skopeo inspect docker://docker.io/'${DOCKERHUB_IMAGE}':development 2>/dev/null' | jq -r '.Labels.build_version' | awk '{print $3}' | grep '\\-ls' || : ''',
            returnStdout: true).trim()
          env.LS_RELEASE_NOTES = sh(
            script: '''cat readme-vars.yml | awk -F \\" '/date: "[0-9][0-9].[0-9][0-9].[0-9][0-9]:/ {print $4;exit;}' | sed -E ':a;N;$!ba;s/\\r{0,1}\\n/\\\\n/g' ''',
            returnStdout: true).trim()
          env.GITHUB_DATE = sh(
            script: '''date '+%Y-%m-%dT%H:%M:%S%:z' ''',
            returnStdout: true).trim()
          env.COMMIT_SHA = sh(
            script: '''git rev-parse HEAD''',
            returnStdout: true).trim()
          env.CODE_URL = 'https://github.com/' + env.LS_USER + '/' + env.LS_REPO + '/commit/' + env.GIT_COMMIT
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DOCKERHUB_IMAGE + '/tags/'
          env.PULL_REQUEST = env.CHANGE_ID
          env.LICENSE_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e LICENSE ] ; then
                         cat LICENSE | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
          env.FUNDING_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e ./.github/FUNDING.yml ] ; then
                         cat ./.github/FUNDING.yml | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
        }
        script{
          env.LS_RELEASE_NUMBER = sh(
            script: '''echo ${LS_RELEASE} |sed 's/^.*-ls//g' ''',
            returnStdout: true).trim()
        }
        script{
          env.LS_TAG_NUMBER = sh(
            script: '''#! /bin/bash
                       tagsha=$(git rev-list -n 1 ${LS_RELEASE} 2>/dev/null)
                       if [ "${tagsha}" == "${COMMIT_SHA}" ]; then
                         echo ${LS_RELEASE_NUMBER}
                       elif [ -z "${GIT_COMMIT}" ]; then
                         echo ${LS_RELEASE_NUMBER}
                       else
                         echo $((${LS_RELEASE_NUMBER} + 1))
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* #######################
       Package Version Tagging
       ####################### */
    // Grab the current package versions in Git to determine package tag
    stage("Set Package tag"){
      steps{
        script{
          env.PACKAGE_TAG = sh(
            script: '''#!/bin/bash
                       if [ -e package_versions.txt ] ; then
                         cat package_versions.txt | md5sum | cut -c1-8
                       else
                         echo none
                       fi''',
            returnStdout: true).trim()
        }
      }
    }
    /* ########################
       External Release Tagging
       ######################## */
    // If this is a custom json endpoint parse the return to get external tag
    stage("Set ENV custom_json"){
     steps{
       script{
         env.EXT_RELEASE = sh(
           script: '''curl -s ${JSON_URL} | jq -r ". | ${JSON_PATH}" ''',
           returnStdout: true).trim()
         env.RELEASE_LINK = env.JSON_URL
       }
     }
    }
    // Sanitize the release tag and strip illegal docker or github characters
    stage("Sanitize tag"){
      steps{
        script{
          env.EXT_RELEASE_CLEAN = sh(
            script: '''echo ${EXT_RELEASE} | sed 's/[~,%@+;:/]//g' ''',
            returnStdout: true).trim()
        }
      }
    }
    // If this is a development build use live docker endpoints
    stage("Set ENV live build"){
      when {
        branch "development"
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DOCKERHUB_IMAGE
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
          }
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
        }
      }
    }
    // If this is a dev build use dev docker endpoints
    stage("Set ENV dev build"){
      when {
        not {branch "development"}
        environment name: 'CHANGE_ID', value: ''
      }
      steps {
        script{
          env.IMAGE = env.DEV_DOCKERHUB_IMAGE
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          }
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-dev-' + env.COMMIT_SHA
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.DEV_DOCKERHUB_IMAGE + '/tags/'
        }
      }
    }
    // If this is a pull request build use dev docker endpoints
    stage("Set ENV PR build"){
      when {
        not {environment name: 'CHANGE_ID', value: ''}
      }
      steps {
        script{
          env.IMAGE = env.PR_DOCKERHUB_IMAGE
          if (env.MULTIARCH == 'true') {
            env.CI_TAGS = 'amd64-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST + '|arm32v7-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST + '|arm64v8-' + env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          } else {
            env.CI_TAGS = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          }
          env.META_TAG = env.EXT_RELEASE_CLEAN + '-pkg-' + env.PACKAGE_TAG + '-pr-' + env.PULL_REQUEST
          env.CODE_URL = 'https://github.com/' + env.LS_USER + '/' + env.LS_REPO + '/pull/' + env.PULL_REQUEST
          env.DOCKERHUB_LINK = 'https://hub.docker.com/r/' + env.PR_DOCKERHUB_IMAGE + '/tags/'
        }
      }
    }
    // Run ShellCheck
    stage('ShellCheck') {
      when {
        environment name: 'CI', value: 'true'
      }
      steps {
        withCredentials([
          string(credentialsId: 'spaces-key', variable: 'DO_KEY'),
          string(credentialsId: 'spaces-secret', variable: 'DO_SECRET')
        ]) {
          script{
            env.SHELLCHECK_URL = 'https://lsio-ci.ams3.digitaloceanspaces.com/' + env.IMAGE + '/' + env.META_TAG + '/shellcheck-result.xml'
          }
          sh '''curl -sL https://raw.githubusercontent.com/linuxserver/docker-shellcheck/master/checkrun.sh | /bin/bash'''
          sh '''#! /bin/bash
                set -e
                docker pull lsiodev/spaces-file-upload:latest
                docker run --rm \
                -e DESTINATION=\"${IMAGE}/${META_TAG}/shellcheck-result.xml\" \
                -e FILE_NAME="shellcheck-result.xml" \
                -e MIMETYPE="text/xml" \
                -v ${WORKSPACE}:/mnt \
                -e SECRET_KEY=\"${DO_SECRET}\" \
                -e ACCESS_KEY=\"${DO_KEY}\" \
                -t lsiodev/spaces-file-upload:latest \
                python /upload.py'''
        }
      }
    }
    // Use helper containers to render templated files
    stage('Update-Templates') {
      when {
        branch "development"
        environment name: 'CHANGE_ID', value: ''
        expression {
          env.CONTAINER_NAME != null
        }
      }
      steps {
        sh '''#! /bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              docker pull linuxserver/jenkins-builder:latest
              docker run --rm -e CONTAINER_NAME=${CONTAINER_NAME} -e GITHUB_BRANCH=development -v ${TEMPDIR}:/ansible/jenkins linuxserver/jenkins-builder:latest 
              docker pull linuxserver/doc-builder:latest
              docker run --rm -e CONTAINER_NAME=${CONTAINER_NAME} -e GITHUB_BRANCH=development -v ${TEMPDIR}:/ansible/readme linuxserver/doc-builder:latest
              if [ "$(md5sum ${TEMPDIR}/${LS_REPO}/Jenkinsfile | awk '{ print $1 }')" != "$(md5sum Jenkinsfile | awk '{ print $1 }')" ] || \
                 [ "$(md5sum ${TEMPDIR}/${CONTAINER_NAME}/README.md | awk '{ print $1 }')" != "$(md5sum README.md | awk '{ print $1 }')" ] || \
                 [ "$(cat ${TEMPDIR}/${LS_REPO}/LICENSE | md5sum | cut -c1-8)" != "${LICENSE_TAG}" ] || \
                 [ "$(cat ${TEMPDIR}/${LS_REPO}/.github/FUNDING.yml | md5sum | cut -c1-8)" != "${FUNDING_TAG}" ]; then
                mkdir -p ${TEMPDIR}/repo
                git clone https://github.com/${LS_USER}/${LS_REPO}.git ${TEMPDIR}/repo/${LS_REPO}
                git --git-dir ${TEMPDIR}/repo/${LS_REPO}/.git checkout -f development
                cp ${TEMPDIR}/${CONTAINER_NAME}/README.md ${TEMPDIR}/repo/${LS_REPO}/
                cp ${TEMPDIR}/docker-${CONTAINER_NAME}/Jenkinsfile ${TEMPDIR}/repo/${LS_REPO}/
                cp ${TEMPDIR}/docker-${CONTAINER_NAME}/LICENSE ${TEMPDIR}/repo/${LS_REPO}/
                mkdir -p ${TEMPDIR}/repo/${LS_REPO}/.github
                cp ${TEMPDIR}/docker-${CONTAINER_NAME}/.github/FUNDING.yml ${TEMPDIR}/repo/${LS_REPO}/.github/FUNDING.yml
                cd ${TEMPDIR}/repo/${LS_REPO}/
                git --git-dir ${TEMPDIR}/repo/${LS_REPO}/.git add Jenkinsfile README.md LICENSE ./.github/FUNDING.yml
                git --git-dir ${TEMPDIR}/repo/${LS_REPO}/.git commit -m 'Bot Updating Templated Files'
                git --git-dir ${TEMPDIR}/repo/${LS_REPO}/.git push https://LinuxServer-CI:${GITHUB_TOKEN}@github.com/${LS_USER}/${LS_REPO}.git --all
                echo "true" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
              else
                echo "false" > /tmp/${COMMIT_SHA}-${BUILD_NUMBER}
              fi
              mkdir -p ${TEMPDIR}/gitbook
              git clone https://github.com/linuxserver/docker-documentation.git ${TEMPDIR}/gitbook/docker-documentation
              if [[ "${BRANCH_NAME}" == "master" ]] && [[ (! -f ${TEMPDIR}/gitbook/docker-documentation/images/docker-${CONTAINER_NAME}.md) || ("$(md5sum ${TEMPDIR}/gitbook/docker-documentation/images/docker-${CONTAINER_NAME}.md | awk '{ print $1 }')" != "$(md5sum ${TEMPDIR}/${CONTAINER_NAME}/docker-${CONTAINER_NAME}.md | awk '{ print $1 }')") ]]; then
                cp ${TEMPDIR}/${CONTAINER_NAME}/docker-${CONTAINER_NAME}.md ${TEMPDIR}/gitbook/docker-documentation/images/
                cd ${TEMPDIR}/gitbook/docker-documentation/
                git add images/docker-${CONTAINER_NAME}.md
                git commit -m 'Bot Updating Templated Files'
                git push https://LinuxServer-CI:${GITHUB_TOKEN}@github.com/linuxserver/docker-documentation.git --all
              fi
              rm -Rf ${TEMPDIR}'''
        script{
          env.FILES_UPDATED = sh(
            script: '''cat /tmp/${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the Templated files were just updated
    stage('Template-exit') {
      when {
        branch "development"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'FILES_UPDATED', value: 'true'
        expression {
          env.CONTAINER_NAME != null
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* ###############
       Build Container
       ############### */
    // Build Docker container for push to LS Repo
    stage('Build-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh "docker build --no-cache --pull -t ${IMAGE}:${META_TAG} \
        --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
      }
    }
    // Build MultiArch Docker containers for push to LS Repo
    stage('Build-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      parallel {
        stage('Build X86') {
          steps {
            sh "docker build --no-cache --pull -t ${IMAGE}:amd64-${META_TAG} \
            --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
          }
        }
        stage('Build ARMHF') {
          agent {
            label 'ARMHF'
          }
          steps {
            withCredentials([
              [
                $class: 'UsernamePasswordMultiBinding',
                credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
                usernameVariable: 'DOCKERUSER',
                passwordVariable: 'DOCKERPASS'
              ]
            ]) {
              echo 'Logging into DockerHub'
              sh '''#! /bin/bash
                 echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                 '''
              sh "docker build --no-cache --pull -f Dockerfile.armhf -t ${IMAGE}:arm32v7-${META_TAG} \
                           --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
              sh "docker tag ${IMAGE}:arm32v7-${META_TAG} lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh "docker push lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh '''docker rmi \
                    ${IMAGE}:arm32v7-${META_TAG} \
                    lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
            }
          }
        }
        stage('Build ARM64') {
          agent {
            label 'ARM64'
          }
          steps {
            withCredentials([
              [
                $class: 'UsernamePasswordMultiBinding',
                credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
                usernameVariable: 'DOCKERUSER',
                passwordVariable: 'DOCKERPASS'
              ]
            ]) {
              echo 'Logging into DockerHub'
              sh '''#! /bin/bash
                 echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
                 '''
              sh "docker build --no-cache --pull -f Dockerfile.aarch64 -t ${IMAGE}:arm64v8-${META_TAG} \
                           --build-arg ${BUILD_VERSION_ARG}=${EXT_RELEASE} --build-arg VERSION=\"${META_TAG}\" --build-arg BUILD_DATE=${GITHUB_DATE} ."
              sh "docker tag ${IMAGE}:arm64v8-${META_TAG} lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh "docker push lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}"
              sh '''docker rmi \
                    ${IMAGE}:arm64v8-${META_TAG} \
                    lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
            }
          }
        }
      }
    }
    // Take the image we just built and dump package versions for comparison
    stage('Update-packages') {
      when {
        branch "development"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''#! /bin/bash
              set -e
              TEMPDIR=$(mktemp -d)
              if [ "${MULTIARCH}" == "true" ]; then
                LOCAL_CONTAINER=${IMAGE}:amd64-${META_TAG}
              else
                LOCAL_CONTAINER=${IMAGE}:${META_TAG}
              fi
              if [ "${DIST_IMAGE}" == "alpine" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  apk info -v > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              elif [ "${DIST_IMAGE}" == "ubuntu" ]; then
                docker run --rm --entrypoint '/bin/sh' -v ${TEMPDIR}:/tmp ${LOCAL_CONTAINER} -c '\
                  apt list -qq --installed | sed "s#/.*now ##g" | cut -d" " -f1 > /tmp/package_versions.txt && \
                  sort -o /tmp/package_versions.txt  /tmp/package_versions.txt && \
                  chmod 777 /tmp/package_versions.txt'
              fi
              NEW_PACKAGE_TAG=$(md5sum ${TEMPDIR}/package_versions.txt | cut -c1-8 )
              echo "Package tag sha from current packages in buit container is ${NEW_PACKAGE_TAG} comparing to old ${PACKAGE_TAG} from github"
              if [ "${NEW_PACKAGE_TAG}" != "${PACKAGE_TAG}" ]; then
                git clone https://github.com/${LS_USER}/${LS_REPO}.git ${TEMPDIR}/${LS_REPO}
                git --git-dir ${TEMPDIR}/${LS_REPO}/.git checkout -f development
                cp ${TEMPDIR}/package_versions.txt ${TEMPDIR}/${LS_REPO}/
                cd ${TEMPDIR}/${LS_REPO}/
                wait
                git add package_versions.txt
                git commit -m 'Bot Updating Package Versions'
                git push https://LinuxServer-CI:${GITHUB_TOKEN}@github.com/${LS_USER}/${LS_REPO}.git --all
                echo "true" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag updated, stopping build process"
              else
                echo "false" > /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}
                echo "Package tag is same as previous continue with build process"
              fi
              rm -Rf ${TEMPDIR}'''
        script{
          env.PACKAGE_UPDATED = sh(
            script: '''cat /tmp/packages-${COMMIT_SHA}-${BUILD_NUMBER}''',
            returnStdout: true).trim()
        }
      }
    }
    // Exit the build if the package file was just updated
    stage('PACKAGE-exit') {
      when {
        branch "development"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    // Exit the build if this is just a package check and there are no changes to push
    stage('PACKAGECHECK-exit') {
      when {
        branch "development"
        environment name: 'CHANGE_ID', value: ''
        environment name: 'PACKAGE_UPDATED', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
        expression {
          params.PACKAGE_CHECK == 'true'
        }
      }
      steps {
        script{
          env.EXIT_STATUS = 'ABORTED'
        }
      }
    }
    /* #######
       Testing
       ####### */
    // Run Container tests
    stage('Test') {
      when {
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          string(credentialsId: 'spaces-key', variable: 'DO_KEY'),
          string(credentialsId: 'spaces-secret', variable: 'DO_SECRET')
        ]) {
          script{
            env.CI_URL = 'https://lsio-ci.ams3.digitaloceanspaces.com/' + env.IMAGE + '/' + env.META_TAG + '/index.html'
          }
          sh '''#! /bin/bash
                set -e
                docker pull lsiodev/ci:latest
                if [ "${MULTIARCH}" == "true" ]; then
                  docker pull lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker pull lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker tag lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm32v7-${META_TAG}
                  docker tag lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm64v8-${META_TAG}
                fi
                docker run --rm \
                --shm-size=1gb \
                -v /var/run/docker.sock:/var/run/docker.sock \
                -e IMAGE=\"${IMAGE}\" \
                -e DELAY_START=\"${CI_DELAY}\" \
                -e TAGS=\"${CI_TAGS}\" \
                -e META_TAG=\"${META_TAG}\" \
                -e PORT=\"${CI_PORT}\" \
                -e SSL=\"${CI_SSL}\" \
                -e BASE=\"${DIST_IMAGE}\" \
                -e SECRET_KEY=\"${DO_SECRET}\" \
                -e ACCESS_KEY=\"${DO_KEY}\" \
                -e DOCKER_ENV=\"${CI_DOCKERENV}\" \
                -e WEB_SCREENSHOT=\"${CI_WEB}\" \
                -e WEB_AUTH=\"${CI_AUTH}\" \
                -e WEB_PATH=\"${CI_WEBPATH}\" \
                -e DO_REGION="ams3" \
                -e DO_BUCKET="lsio-ci" \
                -t lsiodev/ci:latest \
                python /ci/ci.py'''
        }
      }
    }
    /* ##################
         Release Logic
       ################## */
    // If this is an amd64 only image only push a single image
    stage('Docker-Push-Single') {
      when {
        environment name: 'MULTIARCH', value: 'false'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          echo 'Logging into DockerHub'
          sh '''#! /bin/bash
             echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
             '''
          sh "docker tag ${IMAGE}:${META_TAG} ${IMAGE}:development"
          sh "docker push ${IMAGE}:development"
          sh "docker push ${IMAGE}:${META_TAG}"
          sh '''docker rmi \
                ${IMAGE}:${META_TAG} \
                ${IMAGE}:development || :'''
                
        }
      }
    }
    // If this is a multi arch release push all images and define the manifest
    stage('Docker-Push-Multi') {
      when {
        environment name: 'MULTIARCH', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          sh '''#! /bin/bash
             echo $DOCKERPASS | docker login -u $DOCKERUSER --password-stdin
             '''
          sh '''#! /bin/bash
                if [ "${CI}" == "false" ]; then
                  docker pull lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker pull lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER}
                  docker tag lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm32v7-${META_TAG}
                  docker tag lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} ${IMAGE}:arm64v8-${META_TAG}
                fi'''
          sh "docker tag ${IMAGE}:amd64-${META_TAG} ${IMAGE}:amd64-development"
          sh "docker tag ${IMAGE}:arm32v7-${META_TAG} ${IMAGE}:arm32v7-development"
          sh "docker tag ${IMAGE}:arm64v8-${META_TAG} ${IMAGE}:arm64v8-development"
          sh "docker push ${IMAGE}:amd64-${META_TAG}"
          sh "docker push ${IMAGE}:arm32v7-${META_TAG}"
          sh "docker push ${IMAGE}:arm64v8-${META_TAG}"
          sh "docker push ${IMAGE}:amd64-development"
          sh "docker push ${IMAGE}:arm32v7-development"
          sh "docker push ${IMAGE}:arm64v8-development"
          sh "docker manifest push --purge ${IMAGE}:development || :"
          sh "docker manifest create ${IMAGE}:development ${IMAGE}:amd64-development ${IMAGE}:arm32v7-development ${IMAGE}:arm64v8-development"
          sh "docker manifest annotate ${IMAGE}:development ${IMAGE}:arm32v7-development --os linux --arch arm"
          sh "docker manifest annotate ${IMAGE}:development ${IMAGE}:arm64v8-development --os linux --arch arm64 --variant v8"
          sh "docker manifest push --purge ${IMAGE}:${META_TAG} || :"
          sh "docker manifest create ${IMAGE}:${META_TAG} ${IMAGE}:amd64-${META_TAG} ${IMAGE}:arm32v7-${META_TAG} ${IMAGE}:arm64v8-${META_TAG}"
          sh "docker manifest annotate ${IMAGE}:${META_TAG} ${IMAGE}:arm32v7-${META_TAG} --os linux --arch arm"
          sh "docker manifest annotate ${IMAGE}:${META_TAG} ${IMAGE}:arm64v8-${META_TAG} --os linux --arch arm64 --variant v8"
          sh "docker manifest push --purge ${IMAGE}:development"
          sh "docker manifest push --purge ${IMAGE}:${META_TAG}"
          sh '''docker rmi \
                ${IMAGE}:amd64-${META_TAG} \
                ${IMAGE}:amd64-development \
                ${IMAGE}:arm32v7-${META_TAG} \
                ${IMAGE}:arm32v7-development \
                ${IMAGE}:arm64v8-${META_TAG} \
                ${IMAGE}:arm64v8-development \
                lsiodev/buildcache:arm32v7-${COMMIT_SHA}-${BUILD_NUMBER} \
                lsiodev/buildcache:arm64v8-${COMMIT_SHA}-${BUILD_NUMBER} || :'''
        }
      }
    }
    // If this is a public release tag it in the LS Github
    stage('Github-Tag-Push-Release') {
      when {
        branch "development"
        expression {
          env.LS_RELEASE != env.EXT_RELEASE_CLEAN + '-ls' + env.LS_TAG_NUMBER
        }
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        echo "Pushing New tag for current commit ${EXT_RELEASE_CLEAN}-ls${LS_TAG_NUMBER}"
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/git/tags \
        -d '{"tag":"'${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}'",\
             "object": "'${COMMIT_SHA}'",\
             "message": "Tagging Release '${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}' to development",\
             "type": "commit",\
             "tagger": {"name": "LinuxServer Jenkins","email": "jenkins@linuxserver.io","date": "'${GITHUB_DATE}'"}}' '''
        echo "Pushing New release for Tag"
        sh '''#! /bin/bash
              echo "Data change at JSON endpoint ${JSON_URL}" > releasebody.json
              echo '{"tag_name":"'${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}'",\
                     "target_commitish": "development",\
                     "name": "'${EXT_RELEASE_CLEAN}'-ls'${LS_TAG_NUMBER}'",\
                     "body": "**LinuxServer Changes:**\\n\\n'${LS_RELEASE_NOTES}'\\n**Remote Changes:**\\n\\n' > start
              printf '","draft": false,"prerelease": true}' >> releasebody.json
              paste -d'\\0' start releasebody.json > releasebody.json.done
              curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/releases -d @releasebody.json.done'''
      }
    }
    // Use helper container to sync the current README on master to the dockerhub endpoint
    stage('Sync-README') {
      when {
        environment name: 'CHANGE_ID', value: ''
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        withCredentials([
          [
            $class: 'UsernamePasswordMultiBinding',
            credentialsId: '3f9ba4d5-100d-45b0-a3c4-633fd6061207',
            usernameVariable: 'DOCKERUSER',
            passwordVariable: 'DOCKERPASS'
          ]
        ]) {
          sh '''#! /bin/bash
                docker pull lsiodev/readme-sync
                docker run --rm=true \
                  -e DOCKERHUB_USERNAME=$DOCKERUSER \
                  -e DOCKERHUB_PASSWORD=$DOCKERPASS \
                  -e GIT_REPOSITORY=${LS_USER}/${LS_REPO} \
                  -e DOCKER_REPOSITORY=${IMAGE} \
                  -e GIT_BRANCH=master \
                  lsiodev/readme-sync bash -c 'node sync' '''
        }
      }
    }
    // If this is a Pull request send the CI link as a comment on it
    stage('Pull Request Comment') {
      when {
        not {environment name: 'CHANGE_ID', value: ''}
        environment name: 'CI', value: 'true'
        environment name: 'EXIT_STATUS', value: ''
      }
      steps {
        sh '''curl -H "Authorization: token ${GITHUB_TOKEN}" -X POST https://api.github.com/repos/${LS_USER}/${LS_REPO}/issues/${PULL_REQUEST}/comments \
        -d '{"body": "I am a bot, here are the test results for this PR: \\n'${CI_URL}' \\n'${SHELLCHECK_URL}'"}' '''
      }
    }
  }
  /* ######################
     Send status to Discord
     ###################### */
  post {
    always {
      script{
        if (env.EXIT_STATUS == "ABORTED"){
          sh 'echo "build aborted"'
        }
        else if (currentBuild.currentResult == "SUCCESS"){
          sh ''' curl -X POST --data '{"avatar_url": "https://wiki.jenkins-ci.org/download/attachments/2916393/headshot.png","embeds": [{"color": 1681177,\
                 "description": "**Build:**  '${BUILD_NUMBER}'\\n**CI Results:**  '${CI_URL}'\\n**ShellCheck Results:**  '${SHELLCHECK_URL}'\\n**Status:**  Success\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
        else {
          sh ''' curl -X POST --data '{"avatar_url": "https://wiki.jenkins-ci.org/download/attachments/2916393/headshot.png","embeds": [{"color": 16711680,\
                 "description": "**Build:**  '${BUILD_NUMBER}'\\n**CI Results:**  '${CI_URL}'\\n**ShellCheck Results:**  '${SHELLCHECK_URL}'\\n**Status:**  failure\\n**Job:** '${RUN_DISPLAY_URL}'\\n**Change:** '${CODE_URL}'\\n**External Release:**: '${RELEASE_LINK}'\\n**DockerHub:** '${DOCKERHUB_LINK}'\\n"}],\
                 "username": "Jenkins"}' ${BUILDS_DISCORD} '''
        }
      }
    }
  }
}
