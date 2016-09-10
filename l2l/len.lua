if _G["loadstring"] then
  return function(t)
    local mt = getmetatable(t)
    if not mt or not mt.__len then
      return #t
    end
    return mt.__len(t)
  end
else
  return function(t)
    return #t
  end
end
