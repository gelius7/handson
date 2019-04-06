#!/bin/bash

SHELL_DIR=$(dirname $0)

TEMP_DIR=${SHELL_DIR}/temp

NAME="istio"
NAMESPACE="istio-system"

# util func
source ${SHELL_DIR}/common.sh

title() {
    if [ "${TPUT}" != "" ]; then
        tput clear
    fi

    echo
    _echo "${THIS_NAME}" 3
    echo
    _echo "${CLUSTER_NAME}" 4
}

prepare() {
    mkdir -p ${TEMP_DIR}
}

get_cluster() {

    LIST=${TEMP_DIR}/cluster-list
    kubectl config view -o json | jq -r '.contexts[].name' | sort > ${LIST}

    select_one true

    if [ "${SELECTED}" == "" ]; then
        _error
    fi

    CLUSTER_NAME="${SELECTED}"

    kubectl config use ${CLUSTER_NAME}
}

run() {
    prepare

    get_cluster

    main_menu
}

main_menu() {
    title

    echo
    _echo "1. istio install"
    echo
    _echo "9. istio delete"
    echo
    _echo "x. exit"

    question

    case ${ANSWER} in
        1)
            istio_install
            _read "Press Enter to continue..." 5
            main_menu
            ;;
        9)
            istio_delete
            _read "Press Enter to continue..." 5
            main_menu
            ;;
        x)
            _success "Good bye!"
            ;;
        *)
            main_menu
            ;;
    esac

}

create_namespace() {
    _NAMESPACE=$1

    CHECK=

    kubectl get ns ${_NAMESPACE} > /dev/null 2>&1 || export CHECK=CREATE

    if [ "${CHECK}" == "CREATE" ]; then
        _result "${_NAMESPACE}"

        kubectl create ns ${_NAMESPACE}
    fi
}

istio_init() {
    #helm_check

    ISTIO_TMP=${TEMP_DIR}/istio
    mkdir -p ${ISTIO_TMP}

    CHART=${SHELL_DIR}/charts/istio/istio.yaml
    VERSION=1.0.2

    if [ "${VERSION}" == "" ] || [ "${VERSION}" == "latest" ]; then
        VERSION=$(curl -s https://api.github.com/repos/istio/istio/releases/latest | jq -r '.tag_name')
    fi

    _result "${NAME} ${VERSION}"

    # istio download
    if [ ! -d ${ISTIO_TMP}/${NAME}-${VERSION} ]; then
        if [ "${OS_NAME}" == "darwin" ]; then
            OSEXT="osx"
        else
            OSEXT="linux"
        fi

        URL="https://github.com/istio/istio/releases/download/${VERSION}/istio-${VERSION}-${OSEXT}.tar.gz"

        pushd ${ISTIO_TMP}
        curl -sL "${URL}" | tar xz
        popd
    fi

    ISTIO_DIR=${ISTIO_TMP}/${NAME}-${VERSION}/install/kubernetes/helm/istio

}

istio_install() {
    istio_init

    create_namespace ${NAMESPACE}


    CHART=${SHELL_DIR}/custom-values.yaml

    helm upgrade --install ${NAME} ${ISTIO_DIR} --namespace ${NAMESPACE} --values ${CHART}

}

istio_delete() {
        # helm delete
    helm delete --purge ${NAME}

    helm del --purge istio-init

    # delete crds
    LIST="$(kubectl get crds | grep istio.io | awk '{print $1}')"
    if [ "${LIST}" != "" ]; then
        kubectl delete crds ${LIST}
    fi

    # delete ns
    kubectl delete namespace ${NAMESPACE}
}

run
