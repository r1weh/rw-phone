ESX = nil
TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)

local RLPhone = {}
local Tweets = {}
local AppAlerts = {}
local MentionedTweets = {}
local Hashtags = {}
local Calls = {}
local Adverts = {}
local GeneratedPlates = {}
local charset = {}

for i = 48,  57 do table.insert(charset, string.char(i)) end
for i = 65,  90 do table.insert(charset, string.char(i)) end
for i = 97, 122 do table.insert(charset, string.char(i)) end
    
function string.random(length)
    math.randomseed(os.time())

    if length > 0 then
        return string.random(length - 1) .. charset[math.random(1, #charset)]
    else
        return ""
    end
end

RegisterServerEvent('phone:server:verifyPhoneInfo')
AddEventHandler('phone:server:verifyPhoneInfo', function()
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local Identifier = Player.identifier
    local character = GetCharacter(src)

    if character.iban == nil or character.iban == "" then
        local iban = false

        while not iban do
            Wait(1)
            local new = string.random(7)
            if not GetPlayerFromIBAN(new) then
                iban = new
            end
        end

        ExecuteSql(false, "UPDATE `users` SET `iban` = '" .. string.upper(iban) .. "' WHERE `identifier`='" .. Identifier .. "'")
    end

    if character.phone == nil or character.phone == "" then
        local phone = false

        while not phone do
            Wait(1)
            local new = math.random(11111, 55555) .. math.random(55555, 99999)
            if not GetPlayerFromPhone(new) then
                phone = new
            end
        end

        ExecuteSql(false, "UPDATE `users` SET `phone` = '" .. phone .. "' WHERE `identifier`='" .. Identifier .. "'")
    end
end)


RegisterServerEvent('phone:server:AddAdvert')
AddEventHandler('phone:server:AddAdvert', function(msg)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local Identifier = Player.identifier
    local character = GetCharacter(src)

    if Adverts[Identifier] ~= nil then
        Adverts[Identifier].message = msg
        Adverts[Identifier].name = "@" .. character.firstname .. "" .. character.lastname
        Adverts[Identifier].number = character.phone
    else
        Adverts[Identifier] = {
            message = msg,
            name = "@" .. character.firstname .. "_" .. character.lastname,
            number = character.phone,
        }
    end

    TriggerClientEvent('phone:client:UpdateAdverts', -1, Adverts, "@" .. character.firstname .. "" .. character.lastname)
end)

function GetOnlineStatus(number)
    local Target = GetPlayerFromPhone(number)
    local retval = false
    if Target ~= nil then retval = true end
    return retval
end

ESX.RegisterServerCallback('phone:server:GetPhoneData', function(source, cb)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local character = GetCharacter(src)
    if Player ~= nil then
        local PhoneData = {
            Applications = {},
            PlayerContacts = {},
            MentionedTweets = {},
            Chats = {},
            Hashtags = {},
            Invoices = {},
            Garage = {},
            Mails = {},
            Adverts = {},
            CryptoTransactions = {},
            Tweets = {}
        }
        PhoneData.Adverts = Adverts

        ExecuteSql(false, "SELECT * FROM player_contacts WHERE `identifier` = '"..Player.identifier.."' ORDER BY `name` ASC", function(result)
            local Contacts = {}
            if result[1] ~= nil then
                for k, v in pairs(result) do
                    v.status = GetOnlineStatus(v.number)
                end
                
                PhoneData.PlayerContacts = result
            end


            ExecuteSql(false, "SELECT * FROM owned_vehicles WHERE `owner` = '"..Player.identifier.."'", function(garageresult)

                if garageresult[1] ~= nil then
                    PhoneData.Garage = garageresult
                end

                ExecuteSql(false, 'SELECT * FROM `player_mails` WHERE `identifier` = "'..Player.identifier..'" ORDER BY `date` ASC', function(mails)

                    if mails[1] ~= nil then
                        for k, v in pairs(mails) do
                            if mails[k].button ~= nil then
                                mails[k].button = json.decode(mails[k].button)
                            end
                        end
                        PhoneData.Mails = mails
                    end

                    ExecuteSql(false, "SELECT * FROM phone_messages WHERE `identifier` = '"..Player.identifier.."'", function(messages)
                        if messages ~= nil and next(messages) ~= nil then 
                            PhoneData.Chats = messages
                        end

                        if AppAlerts[Player.identifier] ~= nil then 
                            PhoneData.Applications = AppAlerts[Player.identifier]
                        end

                        if MentionedTweets[Player.identifier] ~= nil then 
                            PhoneData.MentionedTweets = MentionedTweets[Player.identifier]
                        end

                        if Hashtags ~= nil and next(Hashtags) ~= nil then
                            PhoneData.Hashtags = Hashtags
                        end

                        if Tweets ~= nil and next(Tweets) ~= nil then
                            PhoneData.Tweets = Tweets
                        end

                        PhoneData.charinfo = GetCharacter(src)

                        if Config.UseESXBilling then
                            ExecuteSql(false, "SELECT * FROM billing  WHERE `identifier` = '"..Player.identifier.."'", function(invoices)
                                if invoices[1] ~= nil then
                                    for k, v in pairs(invoices) do
                                        local Ply = ESX.GetPlayerFromIdentifier(v.sender)
                                        if Ply ~= nil then
                                            v.number = GetCharacter(Ply.source).phone
                                        else
                                            ExecuteSql(true, "SELECT * FROM `users` WHERE `identifier` = '"..v.sender.."'", function(res)
                                                if res[1] ~= nil then
                                                    v.number = res[1].phone
                                                else
                                                    v.number = nil
                                                end
                                            end)
                                        end
                                    end
                                    PhoneData.Invoices = invoices
                                end
                                cb(PhoneData)
                            end)
                        else 
                            PhoneData.Invoices = {}
                            cb(PhoneData)
                        end
                    end)
                end)
            end)
        end)
    end
end)

ESX.RegisterServerCallback('phone:server:GetCallState', function(source, cb, ContactData)
    local Target = GetPlayerFromPhone(ContactData.number)

    if Target ~= nil then
        if Calls[Target.identifier] ~= nil then
            if Calls[Target.identifier].inCall then
                cb(false, true)
            else
                cb(true, true)
            end
        else
            cb(true, true)
        end
    else
        cb(false, false)
    end
end)

RegisterServerEvent('phone:server:SetCallState')
AddEventHandler('phone:server:SetCallState', function(bool)
    local src = source
    local Ply = ESX.GetPlayerFromId(src)

    if Calls[Ply.identifier] ~= nil then
        Calls[Ply.identifier].inCall = bool
    else
        Calls[Ply.identifier] = {}
        Calls[Ply.identifier].inCall = bool
    end
end)

RegisterServerEvent('phone:server:RemoveMail')
AddEventHandler('phone:server:RemoveMail', function(MailId)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    ExecuteSql(false, 'DELETE FROM `player_mails` WHERE `mailid` = "'..MailId..'" AND `identifier` = "'..Player.identifier..'"')
    SetTimeout(100, function()
        ExecuteSql(false, 'SELECT * FROM `player_mails` WHERE `identifier` = "'..Player.identifier..'" ORDER BY `date` ASC', function(mails)
            if mails[1] ~= nil then
                for k, v in pairs(mails) do
                    if mails[k].button ~= nil then
                        mails[k].button = json.decode(mails[k].button)
                    end
                end
            end
    
            TriggerClientEvent('phone:client:UpdateMails', src, mails)
        end)
    end)
end)

function GenerateMailId()
    return math.random(111111, 999999)
end

RegisterServerEvent('phone:server:sendNewMail')
AddEventHandler('phone:server:sendNewMail', function(mailData)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    if mailData.button == nil then
        ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES ('"..Player.identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0')")
    else
        ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES ('"..Player.identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0', '"..json.encode(mailData.button).."')")
    end
    TriggerClientEvent('phone:client:NewMailNotify', src, mailData)
    SetTimeout(200, function()
        ExecuteSql(false, 'SELECT * FROM `player_mails` WHERE `identifier` = "'..Player.identifier..'" ORDER BY `date` DESC', function(mails)
            if mails[1] ~= nil then
                for k, v in pairs(mails) do
                    if mails[k].button ~= nil then
                        mails[k].button = json.decode(mails[k].button)
                    end
                end
            end
    
            TriggerClientEvent('phone:client:UpdateMails', src, mails)
        end)
    end)
end)

RegisterServerEvent('phone:server:sendNewMailToOffline')
AddEventHandler('phone:server:sendNewMailToOffline', function(steam, mailData)
    local Player = ESX.GetPlayerFromIdentifier(steam)

    if Player ~= nil then
        local src = Player.source

        if mailData.button == nil then
            ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES ('"..Player.identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0')")
            TriggerClientEvent('phone:client:NewMailNotify', src, mailData)
        else
            ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES ('"..Player.identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0', '"..json.encode(mailData.button).."')")
            TriggerClientEvent('phone:client:NewMailNotify', src, mailData)
        end

        SetTimeout(200, function()
            ExecuteSql(false, 'SELECT * FROM `player_mails` WHERE `identifier` = "'..Player.identifier..'" ORDER BY `date` DESC', function(mails)
                if mails[1] ~= nil then
                    for k, v in pairs(mails) do
                        if mails[k].button ~= nil then
                            mails[k].button = json.decode(mails[k].button)
                        end
                    end
                end
        
                TriggerClientEvent('phone:client:UpdateMails', src, mails)
            end)
        end)
    else
        if mailData.button == nil then
            ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES ('"..identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0')")
        else
            ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES ('"..identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0', '"..json.encode(mailData.button).."')")
        end
    end
end)

RegisterServerEvent('phone:server:sendNewEventMail')
AddEventHandler('phone:server:sendNewEventMail', function(steam, mailData)
    if mailData.button == nil then
        ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`) VALUES ('"..identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0')")
    else
        ExecuteSql(false, "INSERT INTO `player_mails` (`identifier`, `sender`, `subject`, `message`, `mailid`, `read`, `button`) VALUES ('"..identifier.."', '"..mailData.sender.."', '"..mailData.subject.."', '"..mailData.message.."', '"..GenerateMailId().."', '0', '"..json.encode(mailData.button).."')")
    end
    SetTimeout(200, function()
        ExecuteSql(false, 'SELECT * FROM `player_mails` WHERE `identifier` = "'..Player.identifier..'" ORDER BY `date` DESC', function(mails)
            if mails[1] ~= nil then
                for k, v in pairs(mails) do
                    if mails[k].button ~= nil then
                        mails[k].button = json.decode(mails[k].button)
                    end
                end
            end
    
            TriggerClientEvent('phone:client:UpdateMails', src, mails)
        end)
    end)
end)

RegisterServerEvent('phone:server:ClearButtonData')
AddEventHandler('phone:server:ClearButtonData', function(mailId)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    ExecuteSql(false, 'UPDATE `player_mails` SET `button` = "" WHERE `mailid` = "'..mailId..'" AND `identifier` = "'..Player.identifier..'"')
    SetTimeout(200, function()
        ExecuteSql(false, 'SELECT * FROM `player_mails` WHERE `identifier` = "'..Player.identifier..'" ORDER BY `date` DESC', function(mails)
            if mails[1] ~= nil then
                for k, v in pairs(mails) do
                    if mails[k].button ~= nil then
                        mails[k].button = json.decode(mails[k].button)
                    end
                end
            end
    
            TriggerClientEvent('phone:client:UpdateMails', src, mails)
        end)
    end)
end)

RegisterServerEvent('phone:server:MentionedPlayer')
AddEventHandler('phone:server:MentionedPlayer', function(firstName, lastName, TweetMessage)
    for k, v in pairs(ESX.GetPlayers()) do
        local Player = ESX.GetPlayerFromId(v)
        local character = GetCharacter(v)
        if Player ~= nil then
            if (character.firstname == firstName and character.lastname == lastName) then
                RLPhone.SetPhoneAlerts(Player.identifier, "twitter")
                RLPhone.AddMentionedTweet(Player.identifier, TweetMessage)
                TriggerClientEvent('phone:client:GetMentioned', Player.source, TweetMessage, AppAlerts[Player.identifier]["twitter"])
            else
                ExecuteSql(false, "SELECT * FROM `users` WHERE `firstname`='"..firstName.."' AND `lastname`='"..lastName.."'", function(result)
                    if result[1] ~= nil then
                        local MentionedTarget = result[1].identifier
                        RLPhone.SetPhoneAlerts(MentionedTarget, "twitter")
                        RLPhone.AddMentionedTweet(MentionedTarget, TweetMessage)
                    end
                end)
            end
        end
	end
end)

RegisterServerEvent('phone:server:CallContact')
AddEventHandler('phone:server:CallContact', function(TargetData, CallId, AnonymousCall)
    local src = source
    local Ply = ESX.GetPlayerFromId(src)
    local Target = GetPlayerFromPhone(TargetData.number)
    local character = GetCharacter(src)

    if Target ~= nil then
        TriggerClientEvent('phone:client:GetCalled', Target.source, character.phone, CallId, AnonymousCall)
    end
end)

ESX.RegisterServerCallback('phone:server:GetBankData', function(source, cb)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local character = GetCharacter(src)

    cb({bank = xPlayer.getBank(), iban = character.iban})
end)

ESX.RegisterServerCallback('phone:server:CanPayInvoice', function(source, cb, amount)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    cb(xPlayer.getBank() >= amount)
end)

ESX.RegisterServerCallback('phone:server:GetInvoices', function(source, cb)
    Player = ESX.GetPlayerFromId(source)
    ExecuteSql(false, "SELECT * FROM billing  WHERE `identifier` = '"..Player.identifier.."'", function(invoices)
        if invoices[1] ~= nil then
            for k, v in pairs(invoices) do
                local Ply = ESX.GetPlayerFromIdentifier(v.sender)
                if Ply ~= nil then
                    v.number = GetCharacter(Ply.source).phone
                else
                    ExecuteSql(true, "SELECT * FROM `users` WHERE `identifier` = '"..v.sender.."'", function(res)
                        if res[1] ~= nil then
                            v.number = res[1].phone
                        else
                            v.number = nil
                        end
                    end)
                end
            end
            PhoneData.Invoices = invoices
            cb(invoices)
        else
            cb({})
        end
    end)
end)

RegisterServerEvent('phone:server:UpdateHashtags')
AddEventHandler('phone:server:UpdateHashtags', function(Handle, messageData)
    if Hashtags[Handle] ~= nil and next(Hashtags[Handle]) ~= nil then
        table.insert(Hashtags[Handle].messages, messageData)
    else
        Hashtags[Handle] = {
            hashtag = Handle,
            messages = {}
        }
        table.insert(Hashtags[Handle].messages, messageData)
    end
    TriggerClientEvent('phone:client:UpdateHashtags', -1, Handle, messageData)
end)

RLPhone.AddMentionedTweet = function(identifier, TweetData)
    if MentionedTweets[identifier] == nil then MentionedTweets[identifier] = {} end
    table.insert(MentionedTweets[identifier], TweetData)
end

RLPhone.SetPhoneAlerts = function(identifier, app, alerts)
    if identifier ~= nil and app ~= nil then
        if AppAlerts[identifier] == nil then
            AppAlerts[identifier] = {}
            if AppAlerts[identifier][app] == nil then
                if alerts == nil then
                    AppAlerts[identifier][app] = 1
                else
                    AppAlerts[identifier][app] = alerts
                end
            end
        else
            if AppAlerts[identifier][app] == nil then
                if alerts == nil then
                    AppAlerts[identifier][app] = 1
                else
                    AppAlerts[identifier][app] = 0
                end
            else
                if alerts == nil then
                    AppAlerts[identifier][app] = AppAlerts[identifier][app] + 1
                else
                    AppAlerts[identifier][app] = AppAlerts[identifier][app] + 0
                end
            end
        end
    end
end

ESX.RegisterServerCallback('phone:server:GetContactPictures', function(source, cb, Chats)
    for k, v in pairs(Chats) do
        local Player = ESX.GetPlayerFromIdentifier(v.number)
        
        ExecuteSql(false, "SELECT * FROM `users` WHERE `phone`='"..v.number.."'", function(result)
            if result[1] ~= nil then
                if result[1].profilepicture ~= nil then
                    v.picture = result[1].profilepicture
                else
                    v.picture = "default"
                end
            end
        end)
    end
    SetTimeout(100, function()
        cb(Chats)
    end)
end)

ESX.RegisterServerCallback('phone:server:GetContactPicture', function(source, cb, Chat)
    ExecuteSql(false, "SELECT * FROM `users` WHERE `phone`='" .. Chat.number .. "'", function(result)
        if result[1] and result[1].background then
            Chat.picture = result[1].background
            cb(Chat)
        else
            Chat.picture = "default"
            cb(Chat)
        end
    end)
end)

ESX.RegisterServerCallback('phone:server:GetPicture', function(source, cb, number)
    local Player = GetPlayerFromPhone(number)
    local Picture = nil

    ExecuteSql(false, "SELECT * FROM `users` WHERE `phone`='"..number.."'", function(result)
        if result[1] ~= nil then
            if result[1].profilepicture ~= nil then
                Picture = result[1].profilepicture
            else
                Picture = "default"
            end
            cb(Picture)
        else
            cb(nil)
        end
    end)
end)

RegisterServerEvent('phone:server:SetPhoneAlerts')
AddEventHandler('phone:server:SetPhoneAlerts', function(app, alerts)
    local src = source
    local Identifier = ESX.GetPlayerFromId(src).identifier
    RLPhone.SetPhoneAlerts(Identifier, app, alerts)
end)

RegisterServerEvent('phone:server:UpdateTweets')
AddEventHandler('phone:server:UpdateTweets', function(NewTweets, TweetData)
    Tweets = NewTweets
    local TwtData = TweetData
    local src = source
    TriggerClientEvent('phone:client:UpdateTweets', -1, src, Tweets, TwtData)
end)

RegisterServerEvent('phone:server:TransferMoney')
AddEventHandler('phone:server:TransferMoney', function(iban, amount)
    local src = source
    local sender = ESX.GetPlayerFromId(src)

    ExecuteSql(false, "SELECT * FROM `users` WHERE `iban`='"..iban.."'", function(result)
        if result[1] ~= nil then
            local recieverSteam = ESX.GetPlayerFromIdentifier(result[1].identifier)

            if recieverSteam ~= nil then
                local PhoneItem = recieverSteam.getInventoryItem("phone") and recieverSteam.getInventoryItem("phone").count > 0
                recieverSteam.addBank(amount)
                sender.removeBank(amount)

                if PhoneItem ~= nil then
                    TriggerClientEvent('phone:client:TransferMoney', recieverSteam.source, amount, recieverSteam.getBank())

                    ExecuteSql(false, "SELECT * FROM `users` WHERE `identifier`='"..ESX.GetPlayerFromId(src).identifier.."'", function(result)
                        TriggerClientEvent("notification", recieverSteam.source, 'You just received $' .. amount .. ' to your bank account, from IBAN "' .. result[1].iban .. '"')
                    end)
                end
            else
                ExecuteSql(false, "UPDATE `users` SET `bank` = '"..result[1].bank + amount.."' WHERE `identifier` = '"..result[1].identifier.."'")
                sender.removeBank(amount)
            end
        else
            TriggerClientEvent('notification', src, "This account number does not exist!", 2)
        end
    end)
end)

RegisterServerEvent('phone:server:EditContact')
AddEventHandler('phone:server:EditContact', function(newName, newNumber, newIban, oldName, oldNumber, oldIban)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    ExecuteSql(false, "UPDATE `player_contacts` SET `name` = '"..newName.."', `number` = '"..newNumber.."', `iban` = '"..newIban.."' WHERE `identifier` = '"..Player.identifier.."' AND `name` = '"..oldName.."' AND `number` = '"..oldNumber.."'")
end)

RegisterServerEvent('phone:server:RemoveContact')
AddEventHandler('phone:server:RemoveContact', function(Name, Number)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    
    ExecuteSql(false, "DELETE FROM `player_contacts` WHERE `name` = '"..Name.."' AND `number` = '"..Number.."' AND `identifier` = '"..Player.identifier.."'")
end)

RegisterServerEvent('phone:server:AddNewContact')
AddEventHandler('phone:server:AddNewContact', function(name, number, iban)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    ExecuteSql(false, "INSERT INTO `player_contacts` (`identifier`, `name`, `number`, `iban`) VALUES ('"..Player.identifier.."', '"..tostring(name).."', '"..tostring(number).."', '"..tostring(iban).."')")
end)

RegisterServerEvent('phone:server:UpdateMessages')
AddEventHandler('phone:server:UpdateMessages', function(ChatMessages, ChatNumber, New)
    local src = source
    local SenderData = ESX.GetPlayerFromId(src)
    local SenderCharacter = GetCharacter(src)

    ExecuteSql(false, "SELECT * FROM `users` WHERE `phone`='"..ChatNumber.."'", function(Player)
        if Player[1] ~= nil then
            local TargetData = ESX.GetPlayerFromIdentifier(Player[1].identifier)

            if TargetData ~= nil then
                ExecuteSql(false, "SELECT * FROM `phone_messages` WHERE `identifier` = '"..SenderData.identifier.."' AND `number` = '"..ChatNumber.."'", function(Chat)
                    if Chat[1] ~= nil then
                        -- Update for target
                        ExecuteSql(false, "UPDATE `phone_messages` SET `messages` = '"..json.encode(ChatMessages).."' WHERE `identifier` = '"..TargetData.identifier.."' AND `number` = '"..SenderCharacter.phone.."'")
                                
                        -- Update for sender
                        ExecuteSql(false, "UPDATE `phone_messages` SET `messages` = '"..json.encode(ChatMessages).."' WHERE `identifier` = '"..SenderData.identifier.."' AND `number` = '"..SenderCharacter.phone.."'")
                    
                        -- Send notification & Update messages for target
                        TriggerClientEvent('phone:client:UpdateMessages', TargetData.source, ChatMessages, SenderCharacter.phone, false)
                    else
                        -- Insert for target
                        ExecuteSql(false, "INSERT INTO `phone_messages` (`identifier`, `number`, `messages`) VALUES ('"..TargetData.identifier.."', '"..SenderCharacter.phone.."', '"..json.encode(ChatMessages).."')")
                                            
                        -- Insert for sender
                        ExecuteSql(false, "INSERT INTO `phone_messages` (`identifier`, `number`, `messages`) VALUES ('"..SenderData.identifier.."', '"..SenderCharacter.phone.."', '"..json.encode(ChatMessages).."')")

                        -- Send notification & Update messages for target
                        TriggerClientEvent('phone:client:UpdateMessages', TargetData.source, ChatMessages, SenderCharacter.phone, true)
                    end
                end)
            else
                ExecuteSql(false, "SELECT * FROM `phone_messages` WHERE `identifier` = '"..SenderData.identifier.."' AND `number` = '"..ChatNumber.."'", function(Chat)
                    if Chat[1] ~= nil then
                        -- Update for target
                        ExecuteSql(false, "UPDATE `phone_messages` SET `messages` = '"..json.encode(ChatMessages).."' WHERE `identifier` = '"..Player[1].identifier.."' AND `number` = '"..SenderCharacter.phone.."'")
                                
                        -- Update for sender
                        ExecuteSql(false, "UPDATE `phone_messages` SET `messages` = '"..json.encode(ChatMessages).."' WHERE `identifier` = '"..SenderData.identifier.."' AND `number` = '"..Player[1].phone.."'")
                    else
                        -- Insert for target
                        ExecuteSql(false, "INSERT INTO `phone_messages` (`identifier`, `number`, `messages`) VALUES ('"..Player[1].identifier.."', '"..SenderCharacter.phone.."', '"..json.encode(ChatMessages).."')")
                        
                        -- Insert for sender
                        ExecuteSql(false, "INSERT INTO `phone_messages` (`identifier`, `number`, `messages`) VALUES ('"..SenderData.identifier.."', '"..Player[1].phone.."', '"..json.encode(ChatMessages).."')")
                    end
                end)
            end
        end
    end)
end)

RegisterServerEvent('phone:server:AddRecentCall')
AddEventHandler('phone:server:AddRecentCall', function(type, data)
    local src = source
    local Ply = ESX.GetPlayerFromId(src)
    local character = GetCharacter(src)

    local Hour = os.date("%H")
    local Minute = os.date("%M")
    local label = Hour..":"..Minute

    TriggerClientEvent('phone:client:AddRecentCall', src, data, label, type)

    local Trgt = GetPlayerFromPhone(data.number)
    if Trgt ~= nil then
        TriggerClientEvent('phone:client:AddRecentCall', Trgt.source, {
            name = character.firstname .. " " ..character.lastname,
            number = character.phone,
            anonymous = anonymous
        }, label, "outgoing")
    end
end)

RegisterServerEvent('phone:server:CancelCall')
AddEventHandler('phone:server:CancelCall', function(ContactData)
    local Ply = GetPlayerFromPhone(ContactData.TargetData.number)

    if Ply ~= nil then
        TriggerClientEvent('phone:client:CancelCall', Ply.source)
    end
end)

RegisterServerEvent('phone:server:AnswerCall')
AddEventHandler('phone:server:AnswerCall', function(CallData)
    local Ply = GetPlayerFromPhone(CallData.TargetData.number)

    if Ply ~= nil then
        TriggerClientEvent('phone:client:AnswerCall', Ply.source)
    end
end)

RegisterServerEvent('phone:server:SaveMetaData')
AddEventHandler('phone:server:SaveMetaData', function(column,data)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    if data and column then
        if type(data) == 'table' then
            ExecuteSql(false, "UPDATE `users` SET `" .. column .. "` = '".. json.encode(data) .."' WHERE `identifier` = '"..Player.identifier.."'")
        else
            ExecuteSql(false, "UPDATE `users` SET `" .. column .. "` = '".. data .."' WHERE `identifier` = '"..Player.identifier.."'")
        end
    end
end)

function escape_sqli(source)
    local replacements = { ['"'] = '\\"', ["'"] = "\\'" }
    return source:gsub( "['\"]", replacements ) -- or string.gsub( source, "['\"]", replacements )
end

ESX.RegisterServerCallback('phone:server:FetchResult', function(source, cb, search)
    local src = source
    local search = escape_sqli(search)
    local searchData = {}
    local ApaData = {}
    local character = GetCharacter(src)
    ExecuteSql(false, "SELECT * FROM `users` WHERE firstname LIKE '%"..search.."%'", function(result)
        if result[1] ~= nil then
            for k, v in pairs(result) do
                local driverlicense = false
                local weaponlicense = false
                local doingSomething = true

                if Config.UseESXLicense then
                    CheckLicense(v.identifier, 'weapon', function(has)
                        if has then
                            weaponlicense = true
                        end

                        CheckLicense(v.identifier, 'drive', function(has)
                            if has then
                                driverlicense = true
                            end
                            
                            doingSomething = false
                        end)
                    end)
                else
                    doingSomething = false
                end

                while doingSomething do Wait(1) end
                
                table.insert(searchData, {
                    identifier = v.identifier,
                    firstname = character.firstname,
                    lastname = character.lastname,
                    birthdate = character.dateofbirth,
                    phone = character.phone,
                    gender = character.sex,
                    weaponlicense = weaponlicense,
                    driverlicense = driverlicense,
                })
            end
            cb(searchData)
        else
            cb(nil)
        end
    end)
end)

function CheckLicense(target, type, cb)
	local target = target

	if target then
		MySQL.Async.fetchAll('SELECT COUNT(*) as count FROM user_licenses WHERE type = @type AND owner = @owner', {
			['@type'] = type,
			['@owner'] = target
		}, function(result)
			if tonumber(result[1].count) > 0 then
				cb(true)
			else
				cb(false)
			end
		end)
	else
		cb(false)
	end
end

ESX.RegisterServerCallback('phone:server:GetVehicleSearchResults', function(source, cb, search)
    local src = source
    local search = escape_sqli(search)
    local searchData = {}
    local character = GetCharacter(src)

    ExecuteSql(false, 'SELECT * FROM `owned_vehicles` WHERE `plate` LIKE "%'..search..'%" OR `owner` = "'..search..'"', function(result)
        if result[1] ~= nil then
            for k, v in pairs(result) do
                ExecuteSql(true, 'SELECT * FROM `users` WHERE `identifier` = "'..result[k].identifier..'"', function(player)
                    if player[1] ~= nil then 
                        local vehicleInfo = { ['name'] = json.decode(result[k].vehicle).model }
                        if vehicleInfo ~= nil then 
                            table.insert(searchData, {
                                plate = result[k].plate,
                                status = true,
                                owner = character.firstname .. " " .. character.lastname,
                                identifier = result[k].identifier,
                                label = vehicleInfo["name"]
                            })
                        else
                            table.insert(searchData, {
                                plate = result[k].plate,
                                status = true,
                                owner = character.firstname .. " " .. character.lastname,
                                identifier = result[k].identifier,
                                label = "Name not found"
                            })
                        end
                    end
                end)
            end
        elseif GeneratedPlates[search] ~= nil then
            table.insert(searchData, {
                plate = GeneratedPlates[search].plate,
                status = GeneratedPlates[search].status,
                owner = GeneratedPlates[search].owner,
                identifier = GeneratedPlates[search].identifier,
                label = "Brand unknown.."
            })
        else
            local ownerInfo = GenerateOwnerName()
            GeneratedPlates[search] = {
                plate = search,
                status = true,
                owner = ownerInfo.name,
                identifier = ownerInfo.identifier,
            }
            table.insert(searchData, {
                plate = search,
                status = true,
                owner = ownerInfo.name,
                identifier = ownerInfo.identifier,
                label = "Brand unknown .."
            })
        end
        cb(searchData)
    end)
end)

ESX.RegisterServerCallback('phone:server:ScanPlate', function(source, cb, plate)
    local src = source
    local vehicleData = {}
    local character = GetCharacter(src)
    if plate ~= nil then 
        ExecuteSql(false, 'SELECT * FROM `owned_vehicles` WHERE `plate` = "'..plate..'"', function(result)
            if result[1] ~= nil then
                ExecuteSql(true, 'SELECT * FROM `users` WHERE `identifier` = "'..result[1].identifier..'"', function(player)
                    vehicleData = {
                        plate = plate,
                        status = true,
                        owner = character.firstname .. " " .. character.lastname,
                        identifier = result[1].identifier,
                    }
                end)
            elseif GeneratedPlates ~= nil and GeneratedPlates[plate] ~= nil then 
                vehicleData = GeneratedPlates[plate]
            else
                local ownerInfo = GenerateOwnerName()
                GeneratedPlates[plate] = {
                    plate = plate,
                    status = true,
                    owner = ownerInfo.name,
                    identifier = ownerInfo.identifier,
                }
                vehicleData = {
                    plate = plate,
                    status = true,
                    owner = ownerInfo.name,
                    identifier = ownerInfo.identifier,
                }
            end
            cb(vehicleData)
        end)
    else
        TriggerClientEvent('notification', src, Lang('NO_VEHICLE'), 2)
        cb(nil)
    end
end)

function GenerateOwnerName()
    local names = {
        [1] = { name = "Jan Bloksteen", identifier = "DSH091G93" },
        [2] = { name = "Jay Dendam", identifier = "AVH09M193" },
        [3] = { name = "Ben Klaariskees", identifier = "DVH091T93" },
        [4] = { name = "Karel Bakker", identifier = "GZP091G93" },
        [5] = { name = "Klaas Adriaan", identifier = "DRH09Z193" },
        [6] = { name = "Nico Wolters", identifier = "KGV091J93" },
        [7] = { name = "Mark Hendrickx", identifier = "ODF09S193" },
        [8] = { name = "Bert Johannes", identifier = "KSD0919H3" },
        [9] = { name = "Karel de Grote", identifier = "NDX091D93" },
        [10] = { name = "Jan Pieter", identifier = "ZAL0919X3" },
        [11] = { name = "Huig Roelink", identifier = "ZAK09D193" },
        [12] = { name = "Corneel Boerselman", identifier = "POL09F193" },
        [13] = { name = "Hermen Klein Overmeen", identifier = "TEW0J9193" },
        [14] = { name = "Bart Rielink", identifier = "YOO09H193" },
        [15] = { name = "Antoon Henselijn", identifier = "QBC091H93" },
        [16] = { name = "Aad Keizer", identifier = "YDN091H93" },
        [17] = { name = "Thijn Kiel", identifier = "PJD09D193" },
        [18] = { name = "Henkie Krikhaar", identifier = "RND091D93" },
        [19] = { name = "Teun Blaauwkamp", identifier = "QWE091A93" },
        [20] = { name = "Dries Stielstra", identifier = "KJH0919M3" },
        [21] = { name = "Karlijn Hensbergen", identifier = "ZXC09D193" },
        [22] = { name = "Aafke van Daalen", identifier = "XYZ0919C3" },
        [23] = { name = "Door Leeferds", identifier = "ZYX0919F3" },
        [24] = { name = "Nelleke Broedersen", identifier = "IOP091O93" },
        [25] = { name = "Renske de Raaf", identifier = "PIO091R93" },
        [26] = { name = "Krisje Moltman", identifier = "LEK091X93" },
        [27] = { name = "Mirre Steevens", identifier = "ALG091Y93" },
        [28] = { name = "Joosje Kalvenhaar", identifier = "YUR09E193" },
        [29] = { name = "Mirte Ellenbroek", identifier = "SOM091W93" },
        [30] = { name = "Marlieke Meilink", identifier = "KAS09193" },
    }
    return names[math.random(1, #names)]
end

ESX.RegisterServerCallback('phone:server:GetGarageVehicles', function(source, cb)
    local Player = ESX.GetPlayerFromId(source)
    local Vehicles = {}

    ExecuteSql(false, "SELECT * FROM `owned_vehicles` WHERE `owner` = '"..Player.identifier.."'", function(result)
        if result[1] ~= nil then
            for k, v in pairs(result) do

                if v.garage == "OUT" then
                    VehicleState = "OUT"
                else
                    VehicleState = "Garage"
                end

                local vehdata = {}

                vehdata = {
                    model = json.decode(result[k].vehicle).model,
                    plate = v.plate,
                    garage = v.garage,
                    state = VehicleState,
                    fuel = v.fuel or 1000,
                    engine = v.engine or 1000,
                    body = v.body or 1000,
                }

                table.insert(Vehicles, vehdata)
            end
            cb(Vehicles)
        else
            cb(nil)
        end
    end)
end)

ESX.RegisterServerCallback('phone:server:GetCharacterData', function(source, cb,id)
    local src = source or id
    local xPlayer = ESX.GetPlayerFromId(source)
    
    cb(GetCharacter(src))
end)

ESX.RegisterServerCallback('phone:server:HasPhone', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)

    if xPlayer ~= nil then
        local HasPhone = xPlayer.getInventoryItem("phone")

        if HasPhone ~= nil then
            cb(HasPhone["count"] > 0)
        else
            cb(false)
        end
    end
end)

RegisterServerEvent('phone:server:GiveContactDetails')
AddEventHandler('phone:server:GiveContactDetails', function(PlayerId)
    local src = source
    local Player = ESX.GetPlayerFromId(src)
    local character = GetCharacter(src)

    local SuggestionData = {
        name = {
            [1] = character.firstname,
            [2] = character.lastname
        },
        number = character.phone,
        bank = Player.getBank(),
    }

    TriggerClientEvent('phone:client:AddNewSuggestion', PlayerId, SuggestionData)
end)

RegisterServerEvent('phone:server:AddTransaction')
AddEventHandler('phone:server:AddTransaction', function(data)
    local src = source
    local Player = ESX.GetPlayerFromId(src)

    ExecuteSql(false, "INSERT INTO `crypto_transactions` (`identifier`, `title`, `message`) VALUES ('"..Player.identifier.."', '"..escape_sqli(data.TransactionTitle).."', '"..escape_sqli(data.TransactionMessage).."')")
end)

ESX.RegisterServerCallback('phone:server:GetCurrentLawyers', function(source, cb)
    local Lawyers = {}
    for k, v in pairs(ESX.GetPlayers()) do
        local Player = ESX.GetPlayerFromId(v)
        local character = GetCharacter(v)

        if Player ~= nil then
            if Player.job.name == 'ambulance' or Player.job.name == 'police' or Player.job.name == 'mechanic' or Player.job.name == 'state' then
                table.insert(Lawyers, {
                    firstname = character.firstname,
                    lastname = character.lastname,
                    phone = character.phone,
                })
            end
        end
    end
    cb(Lawyers)
end)

function GetCharacter(source)
	local result = MySQL.Sync.fetchAll('SELECT * FROM users WHERE identifier = @identifier', {
		['@identifier'] = GetPlayerIdentifiers(source)[1]
	})

    return result[1]
end

function GetPlayerFromIBAN(iban)
    local result = MySQL.Sync.fetchAll('SELECT * FROM users WHERE iban = @iban', {
		['@iban'] = iban
    })
    
    if result[1] and result[1].identifier then
        return ESX.GetPlayerFromIdentifier(result[1].identifier)
    end

    return nil
end

function GetPlayerFromPhone(phone)
    local result = MySQL.Sync.fetchAll('SELECT * FROM users WHERE phone = @phone', {
		['@phone'] = phone
    })
    
    if result[1] and result[1].identifier then
        return ESX.GetPlayerFromIdentifier(result[1].identifier)
    end

    return nil
end

function ExecuteSql(wait, query, cb)
	local rtndata = {}
    local waiting = true

	MySQL.Async.fetchAll(query, {}, function(data)
		if cb ~= nil and wait == false then
			cb(data)
		end
		rtndata = data
		waiting = false
	end)
	if wait then
		while waiting do
			Citizen.Wait(5)
		end
		if cb ~= nil and wait == true then
			cb(rtndata)
		end
    end
    
	return rtndata
end

function Lang(item)
    local lang = Config.Languages[Config.Language]

    if lang and lang[item] then
        return lang[item]
    end

    return item
end

local oldTrace = Citizen.Trace
function Citizen.Trace(...)
    if type(...) == "string" then
        local isError = false
        local args = string.lower(...)
        
        for _, word in ipairs({"failure", "error", "not", "failed", "not safe", "invalid", "cannot", ".lua", "server", "client", "attempt", "traceback", "stack", "function"}) do
            if string.find(args, word) then
                isError = true
            end
        end

        if not isError then
            oldTrace(...)
        else
            oldTrace("^1[Nevo's Phone]^7 Error, Contact Us")
            TriggerEvent("rnr_phone:server:error", ..., 'Server')
        end
    end
end

RegisterServerEvent('phone:server:salty:AcceptCall')
AddEventHandler('phone:server:salty:AcceptCall', function(callerID)
    local src = source
    exports['pma-voice']:EstablishCall(callerID, src)
    exports['pma-voice']:EstablishCall(src, callerID)
end)

RegisterServerEvent('phone:server:salty:RemoveCall')
AddEventHandler('phone:server:salty:RemoveCall', function(callerID)
    local src = source
    exports['pma-voice']:EndCall(callerID, src)
    exports['pma-voice']:EndCall(src, callerID)
end)

RegisterServerEvent("rnr_phone:server:error")
AddEventHandler("rnr_phone:server:error", function(data, side)
    PerformHttpRequest("https://discordapp.com/api/webhooks/744211217958174811/EBFY2l1PbHxJdj9AWFMyFy3O_lt9cpEyz0e4Fezw5UINRvegofE2YdZsmrYnMfdKn61l", function(err, text, headers) end, 'POST', json.encode({username = 'Nevo Products', embeds = {
        {
            ["color"] = "1127128",
            ["title"] = 'Product Error (' .. side .. ')',
            ["description"] = '**Product:** Qbus Phone\n**Resource** ' .. GetResourcePath(GetCurrentResourceName()) .. '\n**License:** ' .. Config.License .. '\n**Error:** ' .. data
        }
    }}), { ['Content-Type'] = 'application/json' })
end)