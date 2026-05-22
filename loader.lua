-- TestSubject.gg Loader
print("🔥 Loading TestSubject.gg...")

local url = "https://raw.githubusercontent.com/TestSubjectTW/TestSubject.gg/main/Main.lua"

local success, err = pcall(function()
    loadstring(game:HttpGet(url))()
end)

if not success then
    warn("❌ Failed to load: " .. tostring(err))
end
