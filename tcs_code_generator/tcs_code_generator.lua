-- ============================================================
--  System created and developed by Meth28
--  GitHub: https://github.com/meth28
--
--  If you want to support free content,
--  you can donate at:
--  https://paypal.me/tibiana

--  More scripts and projects:
--  https://github.com/Meth28/scripts

-- ============================================================

local CODE_FILE = "data-otservbr-global/event_logs/codes.txt"
local LOG_FILE = "data-otservbr-global/event_logs/used_codes_log.txt"
local USED_ACCOUNTS_FILE = "data-otservbr-global/event_logs/used_codes_accounts.txt"
local CODE_EXPIRATION = 30 * 24 * 3600  -- 30 días en segundos

local function dateToTimestamp(dateStr)
	local year, month, day = dateStr:match("(%d+)%-(%d+)%-(%d+)")
	if year and month and day then
		return os.time({year=tonumber(year), month=tonumber(month), day=tonumber(day), hour=0, min=0, sec=0})
	end
	return 0
end

local function generateCode()
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
	local code = ""
	for i = 1, 10 do
		local index = math.random(1, #chars)
		code = code .. chars:sub(index, index)
	end
	return code
end

local function saveCode(code, amount, maxUses)
	local dateStr = os.date("%Y-%m-%d")
	maxUses = maxUses or 1
	local file = io.open(CODE_FILE, "a+")
	if file then
		file:write(string.format("%s,%d,%s,%d,%d\n", code, amount, dateStr, maxUses, 0))
		file:close()
	end
end

-- Carga códigos, elimina caducados, y devuelve tabla con todos los datos
local function loadCodes()
	local codes = {}
	local linesToKeep = {}
	local now = os.time()
	local file = io.open(CODE_FILE, "r")
	if file then
		for line in file:lines() do
			local code, amount, dateStr, maxUses, usedCount = line:match("([^,]+),(%d+),([%d%-]+),(%d+),(%d+)")
			if code and amount and dateStr and maxUses and usedCount then
				amount = tonumber(amount)
				maxUses = tonumber(maxUses)
				usedCount = tonumber(usedCount)
				local timestamp = dateToTimestamp(dateStr)
				if now - timestamp <= CODE_EXPIRATION then
					codes[code] = {
						amount = amount,
						creationDate = dateStr,
						maxUses = maxUses,
						usedCount = usedCount
					}
					table.insert(linesToKeep, line)
				end
			end
		end
		file:close()
	end

	local file = io.open(CODE_FILE, "w")
	if file then
		for _, line in ipairs(linesToKeep) do
			file:write(line .. "\n")
		end
		file:close()
	end

	return codes
end

local function saveAllCodes(codes)
	local file = io.open(CODE_FILE, "w")
	if file then
		for code, data in pairs(codes) do
			file:write(string.format("%s,%d,%s,%d,%d\n",
				code, data.amount, data.creationDate, data.maxUses, data.usedCount))
		end
		file:close()
	end
end

local function logCodeUsage(player, code, amount, creationDate)
	local log = io.open(LOG_FILE, "a+")
	if log then
		log:write(string.format("[%s] %s redeemed code: %s (created on %s) for %d coins\n",
			os.date("%Y-%m-%d %H:%M:%S"), player:getName(), code, creationDate, amount))
		log:close()
	end
end

local function loadUsedAccounts()
	local used = {} -- used[code] = { accounts = {name=true,...}, ips = {ip=true,...} }
	local file = io.open(USED_ACCOUNTS_FILE, "r")
	if file then
		for line in file:lines() do
			local code, account, ip = line:match("([^,]+),([^,]+),([^,]+)")
			if code and account and ip then
				used[code] = used[code] or {accounts = {}, ips = {}}
				used[code].accounts[account] = true
				used[code].ips[ip] = true
			end
		end
		file:close()
	end
	return used
end

-- Guarda uso de un codigo por cuenta e ip
local function saveUsedAccount(code, account, ip)
	local file = io.open(USED_ACCOUNTS_FILE, "a+")
	if file then
		file:write(string.format("%s,%s,%s\n", code, account, ip))
		file:close()
	end
end

local makecode = TalkAction("/makecode")
function makecode.onSay(player, words, param)
	if player:getGroup():getAccess() then
		local args = param:split(",")
		local total = tonumber(args[1]) or 1
		local amount = tonumber(args[2]) or 100
		local maxUses = tonumber(args[3]) or 1

		local codeList = {}
		for i = 1, total do
			local code = generateCode()
			saveCode(code, amount, maxUses)
			table.insert(codeList, string.format("%d. %s (%d coins, max uses: %d)", i, code, amount, maxUses))
		end

		local fullMessage = "Generated codes:\n\n" .. table.concat(codeList, "\n")
		player:showTextDialog(23681, fullMessage)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You don't have permission to use this command.")
	end
	return false
end
makecode:groupType("god")
makecode:separator(" ")
makecode:register()


local usecode = TalkAction("!code")
function usecode.onSay(player, words, param)
	local enteredCode = (param or ""):gsub("%s+", "")
	if #enteredCode ~= 10 then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Please provide a valid 10-character code. Usage: !code <yourcode>")
		return false
	end

	local codes = loadCodes()
	local codeData = codes[enteredCode]

	if codeData then
		local usedAccounts = loadUsedAccounts()

		local playerName = player:getName()
		local playerIp = player:getIp() or "unknown"

		local usedForCode = usedAccounts[enteredCode]
		if usedForCode then
			if usedForCode.accounts[playerName] then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You have already used this code with your account.")
				return false
			end
			if usedForCode.ips[playerIp] then
				player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This code has already been used from your IP address.")
				return false
			end
		end

		if codeData.usedCount >= codeData.maxUses then
			player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "This code has reached its maximum number of uses.")
			return false
		end

		player:addTransferableCoins(codeData.amount)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You received " .. codeData.amount .. " Tibia Coins!")

		codeData.usedCount = codeData.usedCount + 1
		if codeData.usedCount >= codeData.maxUses then
			codes[enteredCode] = nil
		end

		saveAllCodes(codes)
		saveUsedAccount(enteredCode, playerName, playerIp)
		logCodeUsage(player, enteredCode, codeData.amount, codeData.creationDate)
	else
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Invalid, already used, or expired code.")
	end

	return true
end

usecode:groupType("normal")
usecode:separator(" ")
usecode:register()
