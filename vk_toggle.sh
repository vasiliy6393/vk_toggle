#!/bin/sh
# AUTHOR: Vasiliy Alekseyevich Pogoreliy
# E-mail: vasiliy@pogoreliy.ru

# скрипт откроет диалоговое окно с запросом ввода строки, возможные форматы:
# 1. целые числа - количество секунд, через которые произойдёт поиск вкладки и нажатие кнопки.
# 2. строка времени, которую принимает sleep. Возможен ввод на русской раскладке, например: 1р2ь25ы.
# символ секунд (s/ы) можно опустить, например: 1h2m25 или 5m25.
# всё время ожидания отображается прогресс-бар.

# изначально скрипт написан по-приколу, но оказался на столько удобным, что решил выложить на GitHub чтобы не потерять.
# иногда работаю над оптимизацией и добавлением новых фичей, багов не замечено

function return_focus(){
    # трижды нажимаем <tab> для перевода фокуса на содержимое вкладки
    for i in {1..3}; do xdotool key "Tab"; done
}
function copy_url(){
    # сохраняем строку адреса открытой вкладки в буфер
    xdotool key "ctrl+l"; xdotool key "ctrl+c";
}
function mouse_click(){
    MPOS="$(xdotool getmouselocation)";
    MPOS_X="$(sed -n -e 's/.*x:\([0-9]\+\).*/\1/p' <<< $MPOS)";
    MPOS_Y="$(sed -n -e 's/.*y:\([0-9]\+\).*/\1/p' <<< $MPOS)";
    xdotool mousemove 535 209; sleep 0.5; xdotool click 1; sleep 0.5;
    xdotool mousemove $MPOS_X $MPOS_Y;
}
function return_tab(){
    id="$1"; start_url_tab="$2";
    xdotool key "ctrl+Tab";
    while true; do
        copy_url;
        return_focus;
        if [[ "$(xclip -o)" != "$start_url_tab" ]]; then xdotool key "ctrl+Tab";
        else break;
        fi
    done
}

if ps aux | grep -Pv "$$|vim " | grep -Pq 'vk_toggle\.sh'; then exit; fi

WAIT_TIME="$(zenity --entry)";
if grep -Pq '^[0-9 hрmьsы]+$' <<< "$WAIT_TIME" ; then
    WAIT_TIME="$(sed 's/ //g' <<< $WAIT_TIME)"; # удаление пробелов
    # перевод секунд, минут и часов в количество секунд
    WAIT_TIME="$(sed 's/s/*1+/gi' <<< $WAIT_TIME)";
    WAIT_TIME="$(sed 's/[mь]/*60+/gi' <<< $WAIT_TIME)";
    WAIT_TIME="$(sed 's/h/*3600+/gi' <<< $WAIT_TIME)";
    # удаление первых и последних символов '+' и '*'
    WAIT_TIME="$(sed 's/^[*+]\|[*+]$//g' <<< $WAIT_TIME)";
    WAIT_TIME=$(($WAIT_TIME)); # выполнение математической операции

    WT_PERC=0;
    for i in $(seq 0 $WAIT_TIME); do
        WT_PERC="$( echo "$i/$WAIT_TIME*100" | bc -l )";
        WT_PERC="$( printf "%.2f" $(bc<<<"scale=3;$WT_PERC" | tr '.' ',') )";
        t=$(($WAIT_TIME-$i))
        h=$(($t/3600)); # вычисляем количество часов
        m=$((($t%3600)/60)); # вычисляем количество минут
        s=$(($t%60)); # вычисляем количество секунд
        # добавляем ведущие нули
        if [[ "$h" -lt "10" ]]; then h="0$h"; fi
        if [[ "$m" -lt "10" ]]; then m="0$m"; fi
        if [[ "$s" -lt "10" ]]; then s="0$s"; fi
        # выводим в нужном формате
        echo -en "$WT_PERC\n# $h:$m:$s ($WT_PERC%)\n";
        sleep 1;
    done | zenity --progress --auto-close --auto-kill  --title="vk toggle" \
                             --text="vk toggle" || exit;
    # если браузер запущен
    if grep -Piq 'firefox' <<< $(ps aux); then
        WAIT="0";
        # переключаем браузер на передний план
        xdotool search --desktop 0 --onlyvisible --class "Firefox" | xargs -L1 --no-run-if-empty \
                                                         xdotool windowactivate;
    else
        # если браузер не запущен
        firefox & # запускаем
        WAIT="10"; # и ждём 10 сек
    fi
    sleep $WAIT;
    copy_url;
    start_url_tab="$(xclip -o)";
    return_focus;
    # смотрим строку адреса каждой вкладки
    while true; do
        copy_url;
        return_focus;
        # если строка адреса содержит 'vk.com'
        if grep -Piq 'vk\.com' <<< $(xclip -o); then
            sleep $WAIT;
            # делаем клик в нужном месте
            mouse_click;
            # если начальная вкладка не 'vk.com' - ищем начальную вкладку
            if ! grep -Piq 'vk\.com' <<< $start_url_tab; then
                return_tab "$id" "$start_url_tab";
            fi
            break;
        else
            # если строка адреса не содержит 'vk.com'
            # переключаемся на следующую вкладку и повторяем проверку
            xdotool key "ctrl+Tab";
            copy_url;
            return_focus;
            # если вернулись к начальной вкладке и 'vk.com' не нашли
            if [[ "$(xclip -o)" == "$start_url_tab" ]]; then
                # открываем страницу vk 'Мои аудиозаписи' в новой вкладке и делаем клик
                firefox "https://vk.com/audios313160849";
                sleep 5;
                mouse_click;
                break 2;
            fi
        fi
    done
fi
