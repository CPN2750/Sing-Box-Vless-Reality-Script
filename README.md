# Sing-Box Vless-Reality Script

這是一個自動化生成與管理 **Sing-Box VLESS Reality** 配置的工具集，適用於 OpenWrt 或 Linux 系統環境。它能自動生成 Reality Keypair、UUID、Short_ID，並更新 `config.json`，同時輸出可直接導入客戶端的 `vless://` 連結與 QRCode。

---

## 📂 專案結構
```
sing-box-vless-reality/
├── README.md
├── config.json-org
├── gen-vless.sh
├── show-vless.sh
└── .gitignore
```

---

## ✨ 功能特色
- 自動生成 Reality Keypair (Private/Public Key)
- 自動生成 UUID 與 Short_ID
- 自動更新 `config.json` 並備份舊檔
- 檢查配置合法性，失敗時自動還原
- 輸出 `vless://` 連結與 QRCode (ANSIUTF8 與 SVG)

---

## ⚙️ 安裝需求
請先安裝必要套件： `sing-box`、`jq`、`qrencode`
+ OpenWRT
	```sh
	# 安裝套件
	opkg install sing-box jq qrencode
	# 或
	apk add sing-box jq qrencode

	# 啟動服務
	uci set sing-box.main.enabled=1
	uci set sing-box.main.user=root
	uci commit sing-box
	/etc/init.d/sing-box enable
	/etc/init.d/sing-box restart

	```

## 🚀 使用方式
1. 複製範本
	將原始配置檔放到 /etc/sing-box/：
	```sh
		cd /etc/sing-box/
		wget https://raw.githubusercontent.com/CPN2750/Sing-Box-Vless-Reality-Script/master/config.json-org
		wget https://raw.githubusercontent.com/CPN2750/Sing-Box-Vless-Reality-Script/master/gen-vless.sh
		wget https://raw.githubusercontent.com/CPN2750/Sing-Box-Vless-Reality-Script/master/show-vless.sh
	```
2. 生成新配置
	+ 設定必要參數 /etc/sing-box/gen-vless.sh
	```
		SERVER=FQDN_or_IP	# 域名orIP
		PORT=Port_Number	# Port
		SNI=SNI_DomainName	# 域名
	```
	+ 執行：
	```sh
		sh gen-vless.sh
	```
	+	此腳本會：
		- 生成新的 Reality Keypair
		- 生成新的 UUID 與 Short_ID
		- 更新 /etc/sing-box/config.json
		- 輸出 vless:// 連結與 QRCode
		- 自動重啟 sing-box

3. 查看現有配置
	+ 執行：
	```sh
		sh show-vless.sh
	```
	+ 此腳本會讀取現有配置並輸出：
		- vless:// 連結
		- QRCode (ANSIUTF8 與 SVG)

---

## ⚠️ 注意事項
+ 請自行修改 SERVER、PORT、SNI 參數。
+ 每次執行 gen-vless.sh 都會重新生成 Reality Keypair、UUID 與 Short_ID。
+ fp 預設為 chrome，可從vless輸出修改。

---

## /etc/sing-box/config.json-org 原始格式
```
{
  "inbounds": [
    {
      "tag": "<< ServerName or IP >>",
      "type": "vless",
      "listen": "::",
      "listen_port": 51030,
      "users": [
        {
          "flow": "xtls-rprx-vision",
          "uuid": "<< UUID >>"
        }
      ],
      "tls": {
        "enabled": true,
        "server_name": "<< SNI >>",
        "reality": {
          "enabled": true,
          "handshake": {
            "server": "<< SNI >>",
            "server_port": 443
          },
          "private_key": "<< Private_Key >>",
          "short_id": [
            "<< Short ID >>"
          ]
        }
      }
    }
  ],
  "outbounds": [
    {
      "type": "direct"
    },
    {
      "tag": "public-key:<< Public_Key >>",
      "type": "block"
    }
  ]
}
```
## /etc/sing-box/gen-vless.sh
```sh
#!/bin/sh

# 設定必要參數
SERVER=FQDN_or_IP		# 域名orIP
PORT=Port_Number		# Port
SNI=SNI_DomainName		# 域名

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


```

## /etc/sing-box/show-vless.sh
```sh
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


```

