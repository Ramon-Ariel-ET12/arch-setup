-- modernx/render/render_elements.lua
-- Render all elements in state.elements into a single master_ass.
-- Per-element type branches: slider, button, (box handled in static_ass).

local mp = require 'mp'
local assdraw = require 'mp.assdraw'
local state = require './state'
local config = require './config'
local hitbox = require './ui.hitbox'
local slider_math = require './ui.slider_math'
local geo = require './utils.geometry'
local ass_render = require './render.ass'
local chapters = require './core.chapters'
local thumbfast_mod = require './ui.thumbfast'
local thumbfast = thumbfast_mod.thumbfast

local M = {}

-- render every element into master_ass
function M.render_elements(master_ass)
    -- forced_title (chapter hover) is computed here because the title element
    -- may be rendered before the slider
    state.forced_title = nil
    if thumbfast.disabled then
        local se = state.slider_element
        local ae = state.elements[state.active_element]
        if config.user_opts.chapter_fmt ~= 'no' and se
            and (ae == se or (not ae and hitbox.mouse_hit(se)))
        then
            local dur = mp.get_property_number('duration', 0)
            if dur > 0 then
                local possec = slider_math.get_slider_value(se) * dur / 100
                local ch = chapters.get_chapter(possec)
                if ch and ch.title and ch.title ~= '' then
                    state.forced_title = string.format(config.user_opts.chapter_fmt, ch.title)
                end
            end
        end
    end

    for n = 1, #state.elements do
        local element = state.elements[n]
        local style_ass = assdraw.ass_new()
        style_ass:merge(element.style_ass)
        ass_render.ass_append_alpha(style_ass, element.layout.alpha, 0)

        if element.eventresponder and (state.active_element == n) then
            if not (element.eventresponder.render == nil) then
                element.eventresponder.render(element)
            end
            if hitbox.mouse_hit(element) then
                if element.styledown then
                    style_ass:append(config.osc_styles.elementDown)
                end
                if (element.softrepeat) and (state.mouse_down_counter >= 15
                        and state.mouse_down_counter % 5 == 0)
                then
                    element.eventresponder[state.active_event_source .. '_down'](element)
                end
                state.mouse_down_counter = state.mouse_down_counter + 1
            end
        end

        if config.user_opts.keyboardnavigation and state.highlight_element == element.name then
            style_ass:append(config.osc_styles.elementHighlight)
        end

        local elem_ass = assdraw.ass_new()
        elem_ass:merge(style_ass)

        if not (element.type == 'button') then
            elem_ass:merge(element.static_ass)
        end

        if element.type == 'slider' then
            local slider_lo = element.layout.slider
            local elem_geo = element.layout.geometry
            local s_min = element.slider.min.value
            local s_max = element.slider.max.value
            local rh = config.user_opts.seekbarhandlesize * elem_geo.h / 2
            local xp

            local pos = element.slider.posF()
            local seekRanges = element.slider.seekRangesF()

            if pos then
                xp = slider_math.get_slider_ele_pos_for(element, pos)
                ass_render.ass_draw_cir_cw(elem_ass, xp, elem_geo.h / 2, rh)
                elem_ass:rect_cw(0, slider_lo.gap, xp, elem_geo.h - slider_lo.gap)
            end

            if seekRanges then
                elem_ass:draw_stop()
                elem_ass:merge(element.style_ass)
                ass_render.ass_append_alpha(elem_ass, element.layout.alpha, config.user_opts.seekrangealpha)
                elem_ass:merge(element.static_ass)

                for _, range in pairs(seekRanges) do
                    local pstart = slider_math.get_slider_ele_pos_for(element, range['start'])
                    local pend = slider_math.get_slider_ele_pos_for(element, range['end'])
                    elem_ass:rect_cw(pstart - rh, slider_lo.gap, pend + rh, elem_geo.h - slider_lo.gap)
                end
            end

            elem_ass:draw_stop()

            -- tooltip
            if not (element.slider.tooltipF == nil) then
                if hitbox.mouse_hit(element) then
                    local sliderpos = slider_math.get_slider_value(element)
                    local tooltiplabel = element.slider.tooltipF(sliderpos)
                    local an = slider_lo.tooltip_an
                    local ty
                    if an == 2 then
                        ty = element.hitbox.y1
                    else
                        ty = element.hitbox.y1 + elem_geo.h / 2
                    end

                    local tx = geo.get_virt_mouse_pos()
                    if slider_lo.adjust_tooltip then
                        if an == 2 then
                            if sliderpos < (s_min + 3) then
                                an = an - 1
                            elseif sliderpos > (s_max - 3) then
                                an = an + 1
                            end
                        elseif sliderpos > (s_max - s_min) / 2 then
                            an = an + 1
                            tx = tx - 5
                        else
                            an = an - 1
                            tx = tx + 10
                        end
                    end

                    -- tooltip label
                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(slider_lo.tooltip_style)
                    ass_render.ass_append_alpha(elem_ass, slider_lo.alpha, 0)
                    elem_ass:append(tooltiplabel)

                    -- thumbnail
                    if not thumbfast.disabled then
                        local osd_w = mp.get_property_number('osd-width')
                        if osd_w then
                            local r_w, r_h = geo.get_virt_scale_factor()

                            local tooltip_font_size = 18
                            local thumbPad = 4
                            local thumbMarginX = 18 / r_w
                            local thumbMarginY = tooltip_font_size + thumbPad + 2 / r_h
                            local thumbX = math.min(osd_w - thumbfast.width - thumbMarginX,
                                math.max(thumbMarginX, tx / r_w - thumbfast.width / 2))
                            local thumbY = (ty - thumbMarginY) / r_h - thumbfast.height

                            thumbX = math.floor(thumbX + 0.5)
                            thumbY = math.floor(thumbY + 0.5)

                            elem_ass:new_event()
                            elem_ass:pos(thumbX * r_w, ty - thumbMarginY - thumbfast.height * r_h)
                            elem_ass:an(7)
                            elem_ass:append(config.osc_styles.Tooltip)
                            elem_ass:draw_start()
                            elem_ass:rect_cw(-thumbPad * r_w, -thumbPad * r_h,
                                (thumbfast.width + thumbPad) * r_w,
                                (thumbfast.height + thumbPad) * r_h)
                            elem_ass:draw_stop()

                            mp.commandv('script-message-to', 'thumbfast', 'thumb',
                                mp.get_property_number('duration', 0) * (sliderpos / 100),
                                thumbX,
                                thumbY
                            )

                            local se = state.slider_element
                            local ae = state.elements[state.active_element]
                            if config.user_opts.chapter_fmt ~= 'no' and se
                                and (ae == se or (not ae and hitbox.mouse_hit(se)))
                            then
                                local dur = mp.get_property_number('duration', 0)
                                if dur > 0 then
                                    local possec = slider_math.get_slider_value(se) * dur / 100
                                    local ch = chapters.get_chapter(possec)
                                    if ch and ch.title and ch.title ~= '' then
                                        elem_ass:new_event()
                                        elem_ass:pos((thumbX + thumbfast.width / 2) * r_w,
                                            thumbY * r_h - tooltip_font_size)
                                        elem_ass:an(an)
                                        elem_ass:append(slider_lo.tooltip_style)
                                        ass_render.ass_append_alpha(elem_ass, slider_lo.alpha, 0)
                                        elem_ass:append(string.format(config.user_opts.chapter_fmt, ch.title))
                                    end
                                end
                            end
                        end
                    end
                else
                    if thumbfast.available then
                        mp.commandv('script-message-to', 'thumbfast', 'clear')
                    end
                end
            end
        elseif element.type == 'button' then
            local buttontext
            if type(element.content) == 'function' then
                buttontext = element.content()
            elseif not (element.content == nil) then
                buttontext = element.content
            end

            buttontext = buttontext:gsub(':%((.?.?.?)%) unknown ', ':%(%1%)')

            local maxchars = element.layout.button.maxchars
            local charcount = (buttontext:len()
                + select(2, buttontext:gsub('[^\128-\193]', '')) * 2) / 3
            if not (maxchars == nil) and (charcount > maxchars) then
                local limit = math.max(0, maxchars - 3)
                if charcount > limit then
                    while charcount > limit do
                        buttontext = buttontext:gsub('.[\128-\191]*$', '')
                        charcount = (buttontext:len()
                            + select(2, buttontext:gsub('[^\128-\193]', '')) * 2) / 3
                    end
                    buttontext = buttontext .. '...'
                end
            end

            elem_ass:append(buttontext)

            -- button tooltip
            if not (element.tooltipF == nil) and element.enabled then
                if hitbox.mouse_hit(element) then
                    local an = 1
                    local ty = element.hitbox.y1
                    local tx = geo.get_virt_mouse_pos()

                    if ty < state.osc_param.playresy / 2 then
                        ty = element.hitbox.y2
                        an = 7
                    end

                    local tooltiplabel
                    if type(element.tooltipF) == 'function' then
                        tooltiplabel = element.tooltipF()
                    else
                        tooltiplabel = element.tooltipF
                    end
                    elem_ass:new_event()
                    elem_ass:pos(tx, ty)
                    elem_ass:an(an)
                    elem_ass:append(element.tooltip_style)
                    elem_ass:append(tooltiplabel)
                end
            end
        end

        master_ass:merge(elem_ass)
    end
end

return M
