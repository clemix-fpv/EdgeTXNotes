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
local IS_COLOR_DISPLAY = false
local BW_LETTER_WIDTH = 7

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

local sprites = {}

local function createDefaultNotes()
    -- Do not create default files if NOTES dir contains some files
    local notes_dir = dir(NOTES_DIR)
    if notes_dir == nil then return end
    for _ in notes_dir do return end

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
    local notes_dir = dir(NOTES_DIR)

    if notes_dir == nil then return filelist end

    for fname in notes_dir do
        if string.match(fname, ".txt$") then
            filelist[#filelist+1] = fname
        end
    end
    local list = sortArray(filelist)
    return list

end

local function sizeText(txt)
    -- lcd.sizeText() is not available for BW displays (yet)
    if IS_COLOR_DISPLAY then
        local w, h = lcd.sizeText(txt)
        return w, h
    else
        return string.len(txt) * BW_LETTER_WIDTH, Y_OFFSET
    end
end

local function drawHeadLine(txt)
    local _,h = sizeText(txt)

    if IS_COLOR_DISPLAY then
        h = h + 2
    end

    lcd.drawFilledRectangle(0, 0, LCD_W, h, FORCE)
    lcd.drawText(1, 1, txt, INVERS)
    if IS_COLOR_DISPLAY then
        lcd.drawLine(0, h, LCD_W, h, SOLID, WHITE)
    else
        lcd.drawLine(0, h, LCD_W, h, SOLID, ERASE)
    end
end


--------------------------------------------------------------------
--- Begin class Sprite
--------------------------------------------------------------------
Sprite = {}
function Sprite:readASCII(ascii)
    local data = {[1]={}}
    local x=1
    local y=1
    local x_max = 0;
    for line in string.gmatch(ascii, "[^\r\n]+") do
        for char in string.gmatch(line, "[.RB]") do
            if char == "R" then
                data[y][x] = RED
            end
            if char == "B" then
                data[y][x] = BLACK
            end
            if char == "." then
                data[y][x] = WHITE
            end
            if x > x_max then
                x_max = x
            end
            x = x + 1
        end
        y = y + 1
        x = 1
        data[y] = {}
    end

    self.x = x_max
    self.y = y -1
    self.data = data
end

function Sprite:draw(x_pos, y_pos)
    return self:drawCenter(x_pos,y_pos, self.x, self.y)
end

function Sprite:drawCenter(x_pos, y_pos, w_pos, h_pos)
    if w_pos > self.x then
        x_pos = x_pos + math.floor((w_pos - self.x)/2)
    end
    if h_pos > self.y then
        y_pos = y_pos + math.floor((h_pos - self.y)/2)
    end
    for y = 1, self.y, 1 do
        for x = 1, self.x, 1 do
            if self.data[y][x] ~= WHITE then
                lcd.drawPoint(x+x_pos, y+y_pos, self.data[y][x])
            end
        end
    end
    return self.x, self.y
end

function Sprite:mirrorY()
    local data = {}
    for y = 1, self.y, 1 do
        data[y] = {}
        for x = 1, self.x, 1 do
            data[y][x] = WHITE
        end
    end

    for y = 1, self.y, 1 do
        for x = self.x, 1, -1 do
            local yn = y
            local xn = self.x - x + 1
            data[yn][xn] = self.data[y][x]
        end
    end
    self.data = data
    return self
end

function Sprite:mirrorX()
    local data = {}
    for y = 1, self.y, 1 do
        data[y] = {}
        for x = 1, self.x, 1 do
            data[y][x] = WHITE
        end
    end

    for y = self.y, 1, -1 do
        for x = 1, self.x, 1 do
            local yn = self.y - y + 1
            local xn = x
            data[yn][xn] = self.data[y][x]
        end
    end
    self.data = data
    return self
end

function Sprite:rotateCCW()
    local data = {}

    for x = 1, self.x, 1 do
        data[x] = {}
    end
    for y = self.y, 1, -1 do
        for x = 1, self.x, 1 do
            local yn = x
            local xn = y
            data[x][y] = self.data[y][x]
        end
    end
    self.x, self.y = self.y, self.x
    self.data = data
    return self
end

function Sprite:new(ascii)
    local o = {}
    setmetatable(o, self)
    self.__index = self
    o:readASCII(ascii)
    return o
end

--------------------------------------------------------------------
--- END class Sprite
--------------------------------------------------------------------

local  function drawUTF8(x_pos, y_pos, letter)
    local utf8_to_sprite = {
        --[[←]]
        ["\226\134\144"] = "arrow_left",
        --[[→]]
        ["\226\134\146"] = "arrow_right",
        --[[↑]]
        ["\226\134\145"] = "arrow_up",
        --[[↓]]
        ["\226\134\147"] = "arrow_down",
        --[[↘]]
        ["\226\134\152"] = "arrow_down_right",
        --[[↙]]
        ["\226\134\153"] = "arrow_down_left",
        --[[↗]]
        ["\226\134\151"] = "arrow_up_right",
        --[[↖]]
        ["\226\134\150"] = "arrow_up_left"
    }

    local wh, hh = sizeText("O")

    if utf8_to_sprite[letter] ~= nil then
        return sprites[utf8_to_sprite[letter]]:drawCenter(x_pos, y_pos, wh, hh)
    end

    wh, hh = sizeText("???")
    lcd.drawText(x_pos, y_pos, "???")
    return wh, hh
end

local function drawLineColor(x, y, line)
    local special_char = ""
    local need_special_char = 0
    local x_start = x
    local x_offset = 0
    local y_offset = 0
    local y_max = 0

    for c in string.gmatch(line, ".") do
        if need_special_char > 0 then
            special_char = special_char .. c
            need_special_char = need_special_char - 1

            if need_special_char == 0 then
                x_offset, y_offset = drawUTF8(x, y, special_char)

                if y_offset > y_max then
                    y_max = y_offset
                end
                special_char = ""
                x = x + x_offset
            end
            goto continue
        end
        if bit32.band(string.byte(c), 240) == 240 then
            special_char = special_char .. c
            need_special_char = 3
            goto continue
        end
        if bit32.band(string.byte(c), 224) == 224 then
            need_special_char = 2
            special_char = special_char .. c
            goto continue
        end
        if bit32.band(string.byte(c), 192) == 192 then
            special_char = special_char .. c
            need_special_char = 1
            goto continue
        end

        x_offset, y_offset = sizeText(c)
        if y_offset > y_max then y_max = y_offset end
        lcd.drawText(x, y, c)
        x = x + x_offset
        -- do something with c
        ::continue::
    end

    return x - x_start, y_max
end

local function drawLineBW(x, y, line)
    line = string.gsub(line, "(\226\134.)", utf8_map) -- replace arrows
    lcd.drawText(x, y, line);
    return string.len(line) * 7, Y_OFFSET
end

local function drawLine(x, y, line)
    if IS_COLOR_DISPLAY then
        return drawLineColor(x,y,line)
    else
        return drawLineBW(x,y,line)
    end
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
            local height
            local width

            lcd.clear()

            self.max_x = 0
            for _, line in pairs(self.lines) do
                width, height = drawLine(x,y, line)
                y = y + height

                if self.max_x < width then
                    self.max_x = width
                end
            end

            drawHeadLine(self.title)
        end,

        do_scroll_x = function (self, step)
            if step > 0 then
                if self.scroll_x < 0 then
                    self.scroll_x = self.scroll_x + step
                end
            else
                if self.max_x > LCD_W then
                    if self.max_x - LCD_W > -1 * self.scroll_x then
                        self.scroll_x = self.scroll_x + step
                    end
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

            local y = Y_OFFSET_TITLE + Y_PADDING
            for i, fname in pairs(self.files) do
                local flags = 0
                if i == self.current_selection then
                    flags = INVERS
                end
                lcd.drawText(X_PADDING, y, fnameToDisplay(fname), flags)
                y = y + Y_OFFSET
            end

            drawHeadLine("Notes")
        end,

        handleEvent = function(self, ev)
            if ev == EVT_VIRTUAL_ENTER then
                if #self.files >= self.current_selection then
                    local fname = self.files[self.current_selection]
                    return screenViewFile(fnameToDisplay(fname), fname)
                end
                return self
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

local function init_sprites()
    local arrow_up =
[[...BB...
  ..BBBB..
  .BBBBBB.
  BBBBBBBB
  ..BBBB..
  ..BBBB..
  ..BBBB..
  ..BBBB..]]

    local arrow_up_right =
[[...BBBBB
  ....BBBB
  ...BBBBB
  ..BBBBBB
  .BBBB..B
  BBBB....
  .BB.....]]

    sprites["arrow_up"] = Sprite:new(arrow_up)
    sprites["arrow_down"] = Sprite:new(arrow_up):mirrorX()
    sprites["arrow_left"] = Sprite:new(arrow_up):rotateCCW()
    sprites["arrow_right"] = Sprite:new(arrow_up):mirrorX():rotateCCW()
    sprites["arrow_up_right"] = Sprite:new(arrow_up_right)
    sprites["arrow_down_right"] = Sprite:new(arrow_up_right):mirrorX()
    sprites["arrow_down_left"] = Sprite:new(arrow_up_right):mirrorX():mirrorY()
    sprites["arrow_up_left"] = Sprite:new(arrow_up_right):mirrorY()
end

local function init()
    init_sprites()
    createDefaultNotes()
    ctxScreen = listScreen(readFiles())

    if lcd.sizeText ~= nil then
        IS_COLOR_DISPLAY = true
        _, Y_OFFSET = lcd.sizeText("O")
        Y_OFFSET_TITLE = Y_OFFSET + 1
    end
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
