-- Reorder record references among explicitly supplied visible slots.
-- Callers own visibility, selection, drag state and view refreshes.
local _, addon = ...
local VisibleSlotOrder = {}
addon.VisibleSlotOrder = VisibleSlotOrder

-- insertionPosition is a gap in the original visible sequence (1..count+1),
-- not a destination slot. Hidden slots and the records table itself stay intact.
function VisibleSlotOrder.Move(records, slots, sourcePosition, insertionPosition)
    if type(sourcePosition) ~= "number" or sourcePosition % 1 ~= 0
        or not slots[sourcePosition]
        or type(insertionPosition) ~= "number" or insertionPosition % 1 ~= 0
        or insertionPosition < 1 or insertionPosition > #slots + 1 then
        return false
    end
    if insertionPosition > sourcePosition then
        insertionPosition = insertionPosition - 1
    end
    if insertionPosition == sourcePosition then return false end

    local ordered = {}
    for position, slot in ipairs(slots) do
        ordered[position] = records[slot]
    end
    local moved = table.remove(ordered, sourcePosition)
    table.insert(ordered, insertionPosition, moved)
    for position, slot in ipairs(slots) do
        records[slot] = ordered[position]
    end
    return true
end
