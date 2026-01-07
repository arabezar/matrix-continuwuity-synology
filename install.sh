#!/bin/bash

VERSION="0.0.1" # Версия скрипта

DOCKER_PATH="/var/packages/ContainerManager/shares/docker"
MATRIX_PRJ_NAME_DEFAULT="matrix-continuwuity"
TEMPLATES_URL_BASE="https://github.com/arabezar/howto-synology-matrix-continuwuity/raw/refs/heads/main"

# Проверка наличия необходимых утилит и условий
echo "Установка Matrix Continuwuity + LiveKit in Docker v${VERSION}..."
echo "Проверка необходимых условий..."
[ "$(whoami)" != "root" ] && echo "❌ Необходимо выполнять скрипт под пользователем root" && exit 255
[ -z "$(which docker)" ] && echo "❌ Docker не установлен" && exit 254
[ ! -d "${DOCKER_PATH}" ] && echo "❌ Не найдена папка проектов Container Manager" && exit 253

# Определение папки проекта
[[ "$(realpath .)" == "$(realpath ${DOCKER_PATH})"* ]] && MATRIX_PRJ_NAME="$(realpath --relative-to="$(realpath ${DOCKER_PATH})" .)" || MATRIX_PRJ_NAME="${MATRIX_PRJ_NAME_DEFAULT}"
[ "${MATRIX_PRJ_NAME}" = "." ] && MATRIX_PRJ_NAME="${MATRIX_PRJ_NAME_DEFAULT}"
read -p "Задайте папку проекта [${MATRIX_PRJ_NAME}] (Enter - подтвердить): " MATRIX_PRJ_NAME_NEW
[ -n "${MATRIX_PRJ_NAME_NEW}" ] && MATRIX_PRJ_NAME="${MATRIX_PRJ_NAME_NEW}"
[ -z "${MATRIX_PRJ_NAME}" ] && echo "❌ Не задана папка проекта Container Manager" && exit 252
mkdir -p "${DOCKER_PATH}/${MATRIX_PRJ_NAME}/db"
cd "${DOCKER_PATH}/${MATRIX_PRJ_NAME}"

# Функция проверки наличия и установки значения параметров конфигурации
check_config_param() {
    # параметры функции
    local _question="$1"
    local _param="$2"
    local _value_def="$3"

    # локальные переменные
    local _value_ask="$_value_def"
    local _value_env=$(sed -nE "s/^${_param}=(\\\"?)(.*)\1.*/\2/p" "$ENV_FILE" 2>/dev/null)
    if [ -n "$_value_env" ]; then
        _value_ask="$_value_env"
    fi

    local _value_new=""
    while [ -z "$_value_new" ]; do
        # запрос параметра у пользователя
        if [ -n "$_value_ask" ]; then
            read -p "$_question [$_value_ask] (Enter - подтвердить): " _value_new
        else
            read -p "$_question: " _value_new
        fi

        # обработка ввода пользователя
        if [ -z "$_value_new" ]; then
            _value_new="$_value_ask"
        fi
    done

    export $_param="$_value_new"

    # сохранение значения параметра
    if [[ "$_value_new" != "$_value_env" ]]; then
        if [ -n "$_value_env" ]; then
            sed -i "s/^$_param=.*/$_param=\"$_value_new\"/" "$ENV_FILE"
        else
            echo "$_param=\"$_value_new\"" >> "$ENV_FILE"
        fi
    fi
}

# Проверка/создание папки проекта
ENV_FILE="${DOCKER_PATH}/${MATRIX_PRJ_NAME}/.env"
[ -f "$ENV_FILE" ] && . "$ENV_FILE"

# Заполнение файла .env
echo "Сбор параметров для развёртывания..."
check_config_param "Основной домен" "DOMAIN_BASE" "example.com"
check_config_param "Домен Matrix" "DOMAIN_MATRIX" "matrix.${DOMAIN_BASE}"
check_config_param "Домен LiveKit" "DOMAIN_LIVEKIT" "matrixrtc-livekit.${DOMAIN_BASE}"
check_config_param "Домен LiveKit Auth" "DOMAIN_AUTH" "matrixrtc-auth.${DOMAIN_BASE}"
check_config_param "Секретная фраза (токен)" "SECRET_TOKEN"
chmod ugo-x "$ENV_FILE"

# Функция для эмуляции envsubst
envsubst_my() {
  eval "echo \"$(cat $1 | sed 's/"/\\"/g')\""
}

# Скачивание и настройка конфигурационных файлов
echo "Загрузка конфигурационных файлов..."
if [ -f "compose.yaml" ]; then
    echo "... compose.yaml найден, загрузка пропущена"
else
    curl -sLO "${TEMPLATES_URL_BASE}/compose.yaml"
fi

if [ -f "continuwuity.toml" ]; then
    echo "... continuwuity.toml найден, загрузка пропущена"
else
    curl -sLO "${TEMPLATES_URL_BASE}/continuwuity.toml.tpl"
    envsubst_my continuwuity.toml.tpl > continuwuity.toml
    rm continuwuity.toml.tpl
fi

if [ -f "livekit.yaml" ]; then
    echo "... livekit.yaml найден, загрузка пропущена"
else
    curl -sLO "${TEMPLATES_URL_BASE}/livekit.yaml.tpl"
    envsubst_my livekit.yaml.tpl > livekit.yaml
    rm livekit.yaml.tpl
fi

if [ -f "proxy.conf.template" ]; then
    echo "... proxy.conf.template найден, загрузка пропущена"
else
    curl -sLO "${TEMPLATES_URL_BASE}/proxy.conf.template"
fi

chmod ugo-x *.yaml continuwuity.toml proxy.conf.template

# Функция проверки существования контейнеров с именами из docker.yaml
check_docker_container() {
    local _name="$1"
    if [ $(docker ps -aq -f name=^/${_name}$) ]; then
        echo "❌ Контейнер ${_name} уже существует, переименуйте его в compose.yaml во избежание конфликтов"
        return 1
    fi
    return 0
}

check_docker_container matrix-internal-proxy
check_docker_container matrix-continuwuity
check_docker_container matrix-auth
check_docker_container matrix-livekit

echo "✅ Установка Matrix Continuwuity завершена, создайте и запустите проект в Container Manager"
