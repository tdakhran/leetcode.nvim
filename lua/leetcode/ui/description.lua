local config = require("leetcode.config")
local log = require("leetcode.logger")
local utils = require("leetcode.utils")

local img_ok, image_api = pcall(require, "image")
local img_sup = img_ok and config.user.image_support

local parser = require("leetcode.parser")
local t = require("leetcode.translator")

local Layout = require("leetcode-ui.layout")
local Group = require("leetcode-ui.component.group")
local Padding = require("leetcode-ui.component.padding")

local NuiSplit = require("nui.split")

---@class lc.ui.Description : NuiSplit
---@field split NuiSplit
---@field parent lc.ui.Question
---@field layout lc-ui.Layout
---@field visible boolean
---@field images table<string, Image>
local Description = NuiSplit:extend("LeetDescription")

-- local DescriptionSplit = Layout:extend("LeetDescription")

local group_id = vim.api.nvim_create_augroup("leetcode_description", { clear = true })

function Description:autocmds()
    vim.api.nvim_create_autocmd("WinResized", {
        group = group_id,
        buffer = self.bufnr,
        callback = function() self:draw() end,
    })
end

function Description:unmount()
    Description.super.unmount(self)
    self = nil
end

function Description:mount()
    self.visible = true
    self:populate()
    Description.super.mount(self)
    self.layout:set_opts({ winid = self.winid, bufnr = self.bufnr })

    local utils = require("leetcode-menu.utils")
    utils.set_buf_opts(self.bufnr, {
        modifiable = false,
        buflisted = false,
        matchpairs = "",
        swapfile = false,
        buftype = "nofile",
        filetype = "leetcode.nvim",
        synmaxcol = 0,
    })
    utils.set_win_opts(self.winid, {
        winhighlight = "Normal:NormalFloat,FloatBorder:FloatBorder",
        wrap = not img_sup,
        colorcolumn = "",
        foldlevel = 999,
        foldcolumn = "1",
        cursorcolumn = false,
        cursorline = false,
        number = false,
        relativenumber = false,
        list = false,
        spell = false,
        signcolumn = "no",
    })
    if not img_ok and config.user.image_support then
        log.error("image.nvim not found but `image_support` is enabled")
    end

    self:draw()
    self:autocmds()
    return self
end

function Description:toggle()
    if self.visible then
        self:hide()
    else
        self:show()
    end

    self.visible = not self.visible
end

function Description:draw()
    self.layout:draw()
    self:draw_imgs()
end

function Description:draw_imgs()
    if not img_sup then return end

    local lines = vim.api.nvim_buf_get_lines(self.bufnr, 1, -1, false)
    for i, line in ipairs(lines) do
        for link in line:gmatch("->%((http[s]?://%S+)%)") do
            local img = self.images[link]

            if not img then
                self.images[link] = {}

                image_api.from_url(link, {
                    buffer = self.bufnr,
                    window = self.winid,
                    with_virtual_padding = true,
                }, function(image)
                    if not image then return end

                    self.images[link] = image
                    image:render({ y = i + 1 })
                end)
            elseif not vim.tbl_isempty(img) then
                img:clear(true)
            end
        end
    end
end

---@private
function Description:populate()
    local q = self.parent.q

    local group = Group({
        position = "center",
    })

    group:append(self.parent.cache.link or "", "leetcode_alt")
    group:endl():endl()

    group:append(q.frontend_id .. ". ", "leetcode_normal")
    group:append(utils.translate(q.title, q.translated_title))
    group:endl()

    group:append(
        t(q.difficulty),
        ({
            ["Easy"] = "leetcode_easy",
            ["Medium"] = "leetcode_medium",
            ["Hard"] = "leetcode_hard",
        })[q.difficulty]
    )
    group:append(" | ")
    group:append(q.likes .. " ", "leetcode_alt")
    if not config.is_cn then group:append(" " .. q.dislikes .. " ", "leetcode_alt") end
    group:append(" | ")
    group:append(
        ("%s %s %s"):format(q.stats.acRate, t("of"), q.stats.totalSubmission),
        "leetcode_alt"
    )
    if not vim.tbl_isempty(q.hints) then
        group:append(" | ")
        group:append("󰛨 " .. t("Hints"), "leetcode_hint")
    end
    group:endl()

    -- local contents = parser:parse(utils.translate(q.content, q.translated_content))

    local layout = Layout({
        group,
        Padding(3),
        -- contents,
    })

    self.layout:set(layout)
end

---@param parent lc.ui.Question
function Description:init(parent)
    Description.super.init(self, {
        relative = "editor",
        position = config.user.description.position,
        size = config.user.description.width,
        enter = false,
        focusable = true,
    })

    self.parent = parent
    self.visible = false
    self.layout = Layout()
    self.images = {}
end

---@type fun(parent: lc.ui.Question): lc.ui.Description
local LeetDescription = Description

return LeetDescription
