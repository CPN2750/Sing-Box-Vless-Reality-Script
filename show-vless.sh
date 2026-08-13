#!/bin/sh
CONF="/etc/sing-box/config.json"
if [ ! -f "$CONF" ]; then
	echo "❌ 找不到 $CONF 配置檔"
	exit 1
fi

# 讀取必要參數
UUID=$(jq -r '.inbounds[0].users[0].uuid' $CONF)
SERVER=$(jq -r '.inbounds[0].tag' $CONF)
PORT=$(jq -r '.inbounds[0].listen_port' $CONF)
SNI=$(jq -r '.inbounds[0].tls.server_name' $CONF)
SID=$(jq -r '.inbounds[0].tls.reality.short_id[0]' $CONF)

# 讀取 public-key (從 outbounds tag)
PUBLIC=$(jq -r '.outbounds[]? | select(.tag? | type=="string") | select(.tag | startswith("public-key:")) | .tag' $CONF | cut -d: -f2)

# 輸出 vless:// 連結
LINK="vless://$UUID@$SERVER:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC&sid=$SID#Reality-$SNI"
echo
echo $LINK
echo

# 在終端輸出 QRCode  
qrencode -t ANSIUTF8 $LINK

# 輸出 QRCode SVG 
qrencode -o /etc/sing-box/QRCode:$SERVER:$PORT.svg -t SVG $LINK
