function fix_path (path)
    return './src/docs' .. path
end

function Link (element)
    element.target = fix_path(element.target)
    return element
end

function Image (element)
    element.src = fix_path(element.src)
    return element
end
