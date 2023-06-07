if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    local lldebugger, run

    lldebugger = require "lldebugger"
    lldebugger.start()
    
    run = love.run
    
    function love.run(...)
        local f = lldebugger.call(run, false, ...)
        
        return function(...) return lldebugger.call(f, false, ...) end
    end
end

local font, text, fheight, timer

function love.load()
    text    = {}
    font    = love.graphics.setNewFont(16)
    timer   = 5
    fheight = font:getHeight()
end

function love.update(dt)
    if #text ~= 1 then timer = timer + dt end

    if timer > 5 then
        timer = 0
        text  = { "Drop your file onto the window." }
    end
end

function love.draw()
    local width, height, _ = love.window.getMode()

    for i, text in ipairs(text) do
        love.graphics.print(text, width * 0.5 - font:getWidth(text) * 0.5, height * 0.25 + i * fheight)
    end
end

function love.filedropped(file)
    local extension, filename, lines, headers

    assert(file:open("r"))

    filename  = file:getFilename()
    extension = filename:match("%.%w+$")
    lines     = {}

    if extension ~= ".csv" then
        text[#text + 1] = "Invalid file type."

        return
    end

    text[#text + 1] = "File '" .. filename .. "' has loaded!"

    for line in file:lines() do
        lines[#lines + 1] = line
    end

    headers = table.remove(lines, 1)

    lines = reverse(lines)

    table.insert(lines, 1, headers)

    file:close()

    buildEmail(lines)
end

function reverse(tbl)
    local result = {}
    
    for i = #tbl, 1, -1 do
        result[#result + 1] = tbl[i]
    end
    
    return result
end

function buildEmail(lines)
    local body, data
    
    body = {}
    data = {}

    body[1] = [[<h3>Weekly LoseIt! Information</h3>
<hr>
<table>
    <thead>
        <tr>
            <th>Date</th>
            <th>Name</th>
            <th>Type</th>
            <th>Amount</th>
            <th>Calories</th>
            <th>Fat (g)</th>
            <th>Protein (g)</th>
            <th>Carbohydrates (g)</th>
            <th>Saturated Fat (g)</th>
            <th>Sugars (g)</th>
            <th>Fiber (g)</th>
            <th>Cholesterol (mg)</th>
            <th>Sodium (mg)</th>
        </tr>
    </thead>
    <tbody>]]

    for i, line in ipairs(lines) do
        local entries = {}

        if i > 1 then
            do
                local quoted = false

                for word in line:gmatch("[^,]+") do
                    if word:sub(1, 1) == '"' or quoted then
                        if not quoted then
                            entries[#entries + 1] = word
                            quoted = true
                        elseif word:sub(-1) == '"' then 
                            entries[#entries] = (entries[#entries] .. "," .. word):gsub('"', "")
                            quoted = false
                        else
                            entries[#entries] = entries[#entries] .. "," .. word
                        end
                    else
                        entries[#entries + 1] = word
                    end
                end
            end
            data[#data + 1] = {
                date          = entries[1],
                name          = entries[2],
                icon          = entries[3],
                type          = entries[4],
                quantity      = entries[5],
                units         = entries[6],
                calories      = entries[7],
                deleted       = entries[8],
                fat           = entries[9],
                protein       = entries[10],
                carbohydrates = entries[11],
                saturated_fat = entries[12],
                sugars        = entries[13],
                fiber         = entries[14],
                cholesterol   = entries[15],
                sodium        = entries[16]
            }
        end
    end

    for _, tbl in pairs(data) do
        body[#body + 1] = string.format([[
        <tr>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
        </tr>]],
        tbl.date,
        tbl.name,
        tbl.type,
        tostring(tonumber(tbl.quantity)) .. " " .. tbl.units,
        tbl.calories,
        tbl.fat,
        tbl.protein,
        tbl.carbohydrates,
        tbl.saturated_fat,
        tbl.sugars,
        tbl.fiber,
        tbl.cholesterol,
        tbl.sodium)
    end

    body[#body + 1] = [[
    </tbody>
</table>
<br>
<h4>Daily Stats</h4>
<table>
    <thead>
        <tr>
            <td>Date</td>
            <td>Calories</td>
            <td>Fat</td>
            <td>Protein</td>
            <td>Carbohydrates</td>
            <td>Saturated Fat</td>
            <td>Sugars</td>
            <td>Fiber</td>
            <td>Cholesterol</td>
            <td>Sodium</td>
        </tr>
    </thead>
    <tbody>]]

    do
        local prev_date, accumulate

        prev_date  = ""
        accumulate = {
            calories      = 0,
            fat           = 0,
            protein       = 0,
            carbohydrates = 0,
            saturated_fat = 0,
            sugars        = 0,
            fiber         = 0,
            cholesterol   = 0,
            sodium        = 0
        }

        for _, tbl in pairs(data) do
            if prev_date == "" then prev_date = tbl.date end
            if prev_date == tbl.date then

                accumulate.calories      = accumulate.calories      + tonumber(tbl.calories ~= "n/a" and tbl.calories or "0")
                accumulate.fat           = accumulate.fat           + tonumber(tbl.fat ~= "n/a" and tbl.fat or "0")
                accumulate.protein       = accumulate.protein       + tonumber(tbl.protein ~= "n/a" and tbl.protein or "0")
                accumulate.carbohydrates = accumulate.carbohydrates + tonumber(tbl.carbohydrates ~= "n/a" and tbl.carbohydrates or "0")
                accumulate.saturated_fat = accumulate.saturated_fat + tonumber(tbl.saturated_fat ~= "n/a" and tbl.saturated_fat or "0")
                accumulate.sugars        = accumulate.sugars        + tonumber(tbl.sugars ~= "n/a" and tbl.sugars or "0")
                accumulate.fiber         = accumulate.fiber         + tonumber(tbl.fiber ~= "n/a" and tbl.fiber or "0")
                accumulate.cholesterol   = accumulate.cholesterol   + tonumber(tbl.cholesterol ~= "n/a" and tbl.cholesterol or "0")
                accumulate.sodium        = accumulate.sodium        + tonumber(tbl.sodium ~= "n/a" and tbl.sodium or "0")
            else
                body[#body + 1] = string.format([[
        <tr>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
            <td>%s</td>
        </tr>]],
                prev_date,
                accumulate.calories,
                accumulate.fat,
                accumulate.protein,
                accumulate.carbohydrates,
                accumulate.saturated_fat,
                accumulate.sugars,
                accumulate.fiber,
                accumulate.cholesterol,
                accumulate.sodium)

                prev_date = tbl.date

                accumulate = {
                    calories      = 0,
                    fat           = 0,
                    protein       = 0,
                    carbohydrates = 0,
                    saturated_fat = 0,
                    sugars        = 0,
                    fiber         = 0,
                    cholesterol   = 0,
                    sodium        = 0
                }
            end
        end
    end

    body[#body + 1] = [[    </tbody>
    </table>]]

    love.filesystem.write("output.html", table.concat(body, ""))
end