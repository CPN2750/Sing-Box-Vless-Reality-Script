#!/bin/sh

# 設定必要參數
SERVER=				# FQDN域名orIP
PORT=				# Port_Number
SNI=				# SNI_DomainName 域名

CONF="/etc/sing-box/config.json"
CONF_ORG="/etc/sing-box/config.json-org"

# 如果 config.json 不存在，先建立
if [ ! -f "$CONF" ]; then
    if [ -f "$CONF_ORG" ]; then
        cp "$CONF_ORG" "$CONF"
    else
        echo "❌ 找不到 $CONF_ORG，無法建立配置檔"
        exit 1
    fi
fi

# 生成 Reality keypair
KEYPAIR=$(sing-box generate reality-keypair)
PRIVATE=$(echo "$KEYPAIR" | grep PrivateKey | awk '{print $2}')
PUBLIC=$(echo "$KEYPAIR" | grep PublicKey | awk '{print $2}')

# 生成 short_id (8位 hex)
SID=$(head -c 8 /dev/urandom | hexdump -v -e '/1 "%02x"')

# 生成新的 UUID
UUID=$(cat /proc/sys/kernel/random/uuid)

# 備份舊 config.json
cp $CONF /etc/sing-box/config.json.bak

# 更新 config.json：合法欄位 + 新 UUID + 檢查/更新/新增 public-key:$PUBLIC
jq --arg server "$SERVER" --arg port "$PORT" --arg sni "$SNI" --arg priv "$PRIVATE" --arg sid "$SID" --arg pub "$PUBLIC" --arg uuid "$UUID" '
  .inbounds[0].tag=$server
  | .inbounds[0].listen_port=($port|tonumber)
  | .inbounds[0].tls.server_name=$sni
  | .inbounds[0].tls.reality.handshake.server=$sni
  | .inbounds[0].tls.reality.private_key=$priv
  | .inbounds[0].tls.reality.short_id=[ $sid ]
  | .inbounds[0].users[0].uuid=$uuid
  | (if any(.outbounds[]?; (.tag? | type=="string") and (.tag | startswith("public-key:")))
       then .outbounds |= map(
              if (.tag? | type=="string") and (.tag | startswith("public-key:"))
              then .tag = "public-key:" + $pub
              else . end
            )
       else .outbounds += [{"tag":"public-key:" + $pub, "type":"block"}]
     end)
' $CONF > /tmp/config.json && mv /tmp/config.json $CONF

# 檢查配置合法性
if ! sing-box check -c $CONF; then
  echo "❌ 配置檢查失敗，已還原備份"
  mv /etc/sing-box/config.json.bak $CONF
  exit 1
fi

# 輸出 vless:// 連結
LINK="vless://$UUID@$SERVER:$PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=$SNI&fp=chrome&pbk=$PUBLIC&sid=$SID#Reality-$SNI"
echo
echo $LINK
echo

# 在終端輸出 QRCode  
qrencode -t ANSIUTF8 $LINK

# 輸出 QRCode SVG 
qrencode -o /etc/sing-box/QRCode:$SERVER:$PORT.svg -t SVG $LINK

# 重啟 sing-box 
/etc/init.d/sing-box restart
