---@diagnostic disable: undefined-global

return {
    s({ trig = "!html", snippetType = "autosnippet" }, {
        t({ "<!DOCTYPE html>",
            "<html lang=\"en\">",
            "<head>",
            "    <meta charset=\"UTF-8\">",
            "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">",
            "    <title>" }),
        i(1, "Title"),
        t({ "</title>",
            "</head>",
            "<body>",
            "    " }),
        i(2),
        t({ "",
            "</body>",
            "</html>" })
    })
}
