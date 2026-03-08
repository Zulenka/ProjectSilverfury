local venomMap = {
["paralysis"] = "curare",

["sensitivity"] = "prefarar",
["asthma"] = "kalmia",
["weariness"] = "vernalius",
["clumsiness"] = "xentio",

["nausea"] = "euphorbia",
["darkshade"] = "darkshade",
["addiction"] = "vardrax",

["anorexia"] = "slike",
["slickness"] = "gecko",

["recklessness"] = "eurypteria",
["shyness"] = "digitalis",
["stupidity"] = "aconite",
["dizziness"] = "larkspur",
["disloyalty"] = "monkshood",
["voyria"] = "voyria",
["loki"] = "loki",
}

function constDWC()

v1 = ""
v2 = ""

if not ak.check("paralysis", 100) then
  v1 = "paralysis"
 elseif not ak.check("asthma", 50) then
  v1 = "asthma"
 elseif not ak.check("weariness", 33) then
  v1 = "weariness"
 else
  v1 = "recklessness"
 end
 
 if not ak.check("clumsiness", 33) then
  v2 = "clumsiness"
 elseif not ak.check("nauea", 50) then
  v2 = "nausea"
 elseif not ak.check("asthma", 50) and v1 ~= "asthma" then
  v2 = "asthma" 
 elseif not ak.check("slickness", 49) then
  v2 = "slickness"
 elseif not ak.check("anorexia", 100) then
  v2 = "anorexia"
 elseif not ak.check("stupidity", 33) then
  v2 = "stupidity"
 else
  v2 = "dizziness"
end
end




