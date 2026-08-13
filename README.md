# Sing-Box Vless-Reality Script

這是一個自動化生成與管理 **Sing-Box VLESS Reality** 配置的工具集，適用於 OpenWrt 或 Linux 系統環境。它能自動生成 Reality Keypair、UUID、Short_ID，並更新 `config.json`，同時輸出可直接導入客戶端的 `vless://` 連結與 QRCode。

---

## 📂 專案結構
	sing-box-vless-reality/
	├── README.md
	├── config.json-org
	├── gen-vless.sh
	├── show-vless.sh
	└── .gitignore

---

## ✨ 功能特色
- 自動生成 Reality Keypair (Private/Public Key)
- 自動生成 UUID 與 Short_ID
- 自動更新 `config.json` 並備份舊檔
- 檢查配置合法性，失敗時自動還原
- 輸出 `vless://` 連結與 QRCode (ANSIUTF8 與 SVG)

---

## ⚙️ 安裝需求
請先安裝必要套件： `jq`、`qrencode`
+ OpenWRT
	```sh
	opkg install jq qrencode
		or
	apk add jq qrencode
	```
+	或在 Linux 系統使用：
	```sh
	apt install jq qrencode -y
	```

---

## 🚀 使用方式
1. 複製範本
	將原始配置檔放到 /etc/sing-box/：
	```sh
	cp config.json-org /etc/sing-box/
	cp gen-vless.sh /etc/sing-box/
	cp show-vless.sh /etc/sing-box/
	```
2. 生成新配置
	+ 設定必要參數 /etc/sing-box/gen-vless.sh
	```
		SERVER=FQDN_or_IP	# 域名orIP
		PORT=55555		# Port
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

