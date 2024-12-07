-- toolName = "TNS|Notes|TNE

local DEFAULT_FILES = {
["Stick_commands.txt"] =
[[← ↑ Betaflight, save ↙ ↘
↘ ↙ VTX Menu
→ + Camera Menu
↙ ↘ Switch to 0mw, exit ↘ ↙
↖ ↗ Switch to 0mw, exit ↗ ↖
]],

["Channels_and_Frequency.txt"] =
[[MHz   HDz  W25  W540  W50  DJI25
5658  R1   CH1   R1    -    CH1
5695  R2   CH2   R2   CH1   CH2
5732  R3   CH3   R3    -    CH3
5769  R4   CH4   R4   CH2   CH4
5806  R5   CH5   R5    -    CH5
5843  R6   CH8   R6   CH8   CH8
5880  R7   CH6   R7   CH3   CH6
5917  R8   CH7   R8    -    CH7
]],

}

local NOTES_DIR = "/NOTES"
local Y_OFFSET = 10
local Y_OFFSET_TITLE = 11
local X_PADDING = 1
local Y_PADDING = 1

local ctxScreen

local utf8_map = {
    --[[←]]
    ["\226\134\144"] = string.char(127),
    --[[→]]
    ["\226\134\146"] = string.char(126),
    --[[↑]]
    ["\226\134\145"] = string.char(130),
    --[[↓]]
    ["\226\134\147"] = string.char(131),
    --[[↘]]
    ["\226\134\152"] = string.char(133),
    --[[↙]]
    ["\226\134\153"] = string.char(134),
    --[[↗]]
    ["\226\134\151"] = string.char(132),
    --[[↖]]
    ["\226\134\150"] = string.char(135),
}


local function createDefaultNotes()
    -- Do not create default files if NOTES dir contains some files
    for _ in dir(NOTES_DIR) do return end

    for name , value in pairs(DEFAULT_FILES) do
        local info = fstat(NOTES_DIR .. "/" .. name)
        if info == nil then
            local file = io.open(NOTES_DIR .. "/" .. name, "w")
            if file ~= nil then
                io.write(file, value)
                io.close(file)
            end
        end

    end
end


local function fnameToDisplay(fname)
    fname = string.sub(fname, 0, -5)
    fname = string.gsub(fname, "_", " ")
    return fname
end


-- Sort array with bubblesort
local function sortArray(arr)
  for i = 1, #arr - 1 do
    for j = 1, #arr - i do
      if arr[j] > arr[j + 1] then
        arr[j], arr[j + 1] = arr[j + 1], arr[j]
      end
    end
  end
  return arr
end

-- Retrieves the key out of a event mask
local function EVT_KEY_MASK(ev)
    return bit32.band(ev, 0x1F)
end

local function readFiles()
    local filelist = {}
    for fname in dir(NOTES_DIR) do
        if string.match(fname, ".txt$") then
            filelist[#filelist+1] = fname
        end
    end
    local list = sortArray(filelist)
    return list

end


local function drawHeadLine(txt)
    lcd.drawFilledRectangle(0, 0, LCD_W, Y_OFFSET_TITLE - 1, FORCE)
    lcd.drawText(1, 1, txt, INVERS)
end


local function screenViewFile(file, f)
    if f == nil then
        error("UNKNOWN FILE " .. f)
        return nil
    end

    f = io.open(NOTES_DIR .. "/" .. f, "r")
    if f == nil then
        error("Unable to open file " .. file)
        return nil
    end

    local buf = ""
    while true do
        local data = io.read(f, 512)
        if #data > 0 then
            buf = buf .. data
        end
        if #data < 512 then
            break
        end
    end
    io.close(f)

    local lines = {}
    for s in string.gmatch(buf, "[^\r\n]+") do
        s = string.gsub(s, "(\226\134.)", utf8_map) -- replace arrows
        lines[#lines + 1] = s
    end

    return {
        lines = lines,
        title = file,
        scroll_y = 0,
        scroll_x = 0,
        wheel_scroll_y = 0,
        max_x = 0,

        draw = function(self)
            local y = self.scroll_y + Y_OFFSET_TITLE + Y_PADDING
            local x = self.scroll_x + X_PADDING

            lcd.clear()

            self.max_x = 0
            for _, line in pairs(self.lines) do
                lcd.drawText(x, y, line)
                -- Hmmm lcd.sizeText() only for color display?!
                -- local tmp = lcd.sizeText(line)
                -- if (tmp > self.max_x) then
                --     self.max_x = tmp
                -- end
                y = y + Y_OFFSET
            end

            drawHeadLine(self.title)
        end,

        do_scroll_x = function (self, step)
            if step > 0 then
                if self.scroll_x < 0 then
                    self.scroll_x = self.scroll_x + step
                end
            else
                if self.max_x - LCD_H < -1 * self.scroll_x then
                    self.scroll_x = self.scroll_x + step
                end
            end
        end,

        do_scroll_y = function (self, step)
            if step > 0 then
                if self.scroll_y < 0 then
                    self.scroll_y = self.scroll_y + step
                end
            else
                if self.scroll_y > (-1 * #self.lines * Y_OFFSET + LCD_H - Y_OFFSET_TITLE) then
                    -- if self.scroll_y > 0 then
                    self.scroll_y = self.scroll_y + step
                end
            end
        end,

        handleEvent = function(self, ev)
            if ev == EVT_EXIT_BREAK then
                if self.scroll_x ~= 0 or self.scroll_y ~= 0 then
                    self.scroll_y = 0
                    self.scroll_x = 0
                else
                    return nil
                end
            end

            if ev == EVT_VIRTUAL_INC then
                if self.wheel_scroll_y > 0 then
                    self:do_scroll_x(-10)
                    self.wheel_scroll_y = 2
                    killEvents(EVT_VIRTUAL_PREV_PAGE)
                    killEvents(EVT_VIRTUAL_NEXT_PAGE)
                else
                    self:do_scroll_y(-5)
                end
            end

            if ev == EVT_VIRTUAL_DEC then
                if self.wheel_scroll_y > 0 then
                    self:do_scroll_x(10)
                    self.wheel_scroll_y = 2
                    killEvents(EVT_VIRTUAL_PREV_PAGE)
                    killEvents(EVT_VIRTUAL_NEXT_PAGE)
                else
                    self:do_scroll_y(5)
                end
            end

            if self.wheel_scroll_y < 2 then
                -- XXX the key is the same for NEXT_PAGE and INC but there is
                --     still a difference 0_o
                if EVT_KEY_MASK(ev) == EVT_KEY_MASK(EVT_VIRTUAL_NEXT_PAGE) or
                   EVT_KEY_MASK(ev) == EVT_KEY_MASK(EVT_VIRTUAL_PREV_PAGE) and
                    ev ~= EVT_VIRTUAL_INC and ev ~= EVT_VIRTUAL_DEC then
                    self.wheel_scroll_y = 1
                end

                if ev == EVT_VIRTUAL_NEXT_PAGE or ev == 69 then
                    self:do_scroll_x(-20)
                end
                if ev == EVT_VIRTUAL_PREV_PAGE or ev == 68 then
                    self:do_scroll_x(20)
                end
            end

            if ev == EVT_VIRTUAL_NEXT_PAGE or ev == EVT_VIRTUAL_PREV_PAGE then
                self.wheel_scroll_y = 0
            end

            return self
        end,
    }
end


local function listScreen(files)
    return {
        files = files,
        current_selection = 1,

        draw = function(self)
            lcd.clear()

            drawHeadLine("Notes")

            local y = Y_OFFSET_TITLE + Y_PADDING
            for i, fname in pairs(self.files) do
                local flags = 0
                if i == self.current_selection then
                    flags = INVERS
                end
                lcd.drawText(X_PADDING, y, fnameToDisplay(fname), flags)
                y = y + Y_OFFSET
            end
        end,

        handleEvent = function(self, ev)
            if ev == EVT_VIRTUAL_ENTER then
                local fname = self.files[self.current_selection]
                return screenViewFile(fnameToDisplay(fname), fname)
            end

            if ev == EVT_VIRTUAL_INC then
                if self.current_selection < #self.files then
                    self.current_selection = self.current_selection + 1
                end
            end
            if ev == EVT_VIRTUAL_DEC then
                if self.current_selection > 1 then
                    self.current_selection = self.current_selection - 1
                end
            end

            return self
        end,
    }
end


local function init()
    createDefaultNotes()
    ctxScreen = listScreen(readFiles())
end

local function printEv(ev)

      mapping = {}
      mapping[EVT_VIRTUAL_NEXT_PAGE] = "EVT_VIRTUAL_NEXT_PAGE"
      mapping[EVT_VIRTUAL_PREV_PAGE] = "EVT_VIRTUAL_PREV_PAGE"
      mapping[EVT_VIRTUAL_ENTER] = "EVT_VIRTUAL_ENTER"
      mapping[EVT_VIRTUAL_ENTER_LONG] = "EVT_VIRTUAL_ENTER_LONG"
      mapping[EVT_VIRTUAL_MENU] = "EVT_VIRTUAL_MENU"
      mapping[EVT_VIRTUAL_MENU_LONG] = "EVT_VIRTUAL_MENU_LONG"
      mapping[EVT_VIRTUAL_NEXT] = "EVT_VIRTUAL_NEXT"
    --  mapping[EVT_VIRTUAL_NEXT_REPT] = "EVT_VIRTUAL_NEXT_REPT"
      mapping[EVT_VIRTUAL_PREV] = "EVT_VIRTUAL_PREV"
    --  mapping[EVT_VIRTUAL_PREV_REPT] = "EVT_VIRTUAL_PREV_REPT"
      mapping[EVT_VIRTUAL_INC] = "EVT_VIRTUAL_INC"
    --  mapping[EVT_VIRTUAL_INC_REPT] = "EVT_VIRTUAL_INC_REPT"
      mapping[EVT_VIRTUAL_DEC] = "EVT_VIRTUAL_DEC"
    --  mapping[EVT_VIRTUAL_DEC_REPT] = "EVT_VIRTUAL_DEC_REPT"

--      mapping[EVT_PAGE_BREAK] = "EVT_PAGE_BREAK"
--      mapping[EVT_PAGE_LONG] = "EVT_PAGE_LONG"
      mapping[EVT_ENTER_BREAK] = "EVT_ENTER_BREAK"
      mapping[EVT_ENTER_LONG] = "EVT_ENTER_LONG"
      mapping[EVT_EXIT_BREAK] = "EVT_EXIT_BREAK"
--      mapping[EVT_PLUS_BREAK] = "EVT_PLUS_BREAK"
--      mapping[EVT_MINUS_BREAK] = "EVT_MINUS_BREAK"
--      mapping[EVT_PLUS_FIRST] = "EVT_PLUS_FIRST"
--      mapping[EVT_MINUS_FIRST] = "EVT_MINUS_FIRST"
--      mapping[EVT_PLUS_REPT] = "EVT_PLUS_REPT"
--      mapping[EVT_MINUS_REPT] = "EVT_MINUS_REPT"

    local bits = "";
    for i = 15, 0,-1 do
        local n = bit32.extract (ev,i,1)
        bits = bits .. n
    end

      if mapping[ev] ~= nil then
        print("EVT: " .. mapping[ev] .. "(".. bits .. ") key:" .. EVT_KEY_MASK(ev))
      else
        print("EVT: " .. ev .. "(".. bits .. ") key:" .. EVT_KEY_MASK(ev) )
      end

end

local function run(ev)

    if ev ~= 0 then
        -- printEv(ev)
        ctxScreen = ctxScreen:handleEvent(ev)
    end

    if ctxScreen == nil then
        ctxScreen = listScreen(readFiles())
    end

    ctxScreen:draw()

    return 0
end

return {
    init = init,
    run = run,
}
