-- Rex configuration
-- Docs: https://www.superlogical.com/rex/docs/customize/config
-- Apply changes with: rex config reload

-- Cmd+Left/Right switch tabs. Binding a key replaces its default
-- (sending the key to the terminal), so no unbind is needed.
rex.bind("cmd+right", "client.tab.next")
rex.bind("cmd+left", "client.tab.previous")
