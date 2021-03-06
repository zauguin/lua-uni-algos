kpse.set_program_name'lualatex'
local normalize = require'lua-uni-normalize'
local nodes_to_nfc, nodes_to_nfd, nodes_to_nfkd = normalize.node.NFC, normalize.node.NFD, normalize.node.NFKD
-- local to_nfc, to_nfd, to_nfkc, to_nfkd = normalize.NFC, normalize.NFD, normalize.NFKC, normalize.NFKD

local all_true = setmetatable({}, {__index = function() return true end})
local function adapt_nodefunction(func, s, ...)
  local head, last
  for _, cp in utf8.codes(s) do
    local n = node.new'glyph'
    n.char, n.font = cp, 1
    head, last = node.insert_after(head, last, n)
  end
  head = func(head, 1, ...)
  local codepoints = {}
  last = 0
  for n in node.traverse(head) do
    last = last + 1
    codepoints[last] = n.char
  end
  return utf8.char(table.unpack(codepoints))
end
local function dostep(orig, nfc, nfd, nfkc, nfkd)
  local our_nfc = adapt_nodefunction(nodes_to_nfc, orig, all_true, true)
  local our_second_nfc = adapt_nodefunction(nodes_to_nfc, nfd, all_true, true) -- Verify that we also normalize fully decomposed things correctly
  local our_nfd = adapt_nodefunction(nodes_to_nfd, orig, all_true)
  -- local our_nfkc = to_nfkc(orig)
  local our_nfkd = adapt_nodefunction(nodes_to_nfkd, orig, all_true)
  if nfc ~= our_nfc or nfc ~= our_second_nfc or nfd ~= our_nfd --[[nfkc ~= our_nfkc]] or nfkd ~= our_nfkd then
  -- if nfc ~= our_nfc or nfd ~= our_nfd or nfkc ~= our_nfkc then
    return {
      orig = orig,
      nfc = nfc ~= our_nfc and our_nfc or nil,
      nfc2 = our_nfc ~= our_second_nfc and our_second_nfc or nil,
      exp_nfc = nfc ~= our_nfc and nfc or nil,
      nfd = nfd ~= our_nfd and our_nfd or nil,
      exp_nfd = nfd ~= our_nfd and nfd or nil,
      -- nfkc = nfkc ~= our_nfkc and our_nfkc or nil,
      -- exp_nfkc = nfkc ~= our_nfkc and nfkc or nil,
      nfkd = nfkd ~= our_nfkd and our_nfkd or nil,
      exp_nfkd = nfkd ~= our_nfkd and nfkd or nil,
    }
  end
  return false
end
local function jointests(last, pos, new)
  -- if not new then os.exit(1) end
  last[1] = last[1] + 1
  if new then
    last[#last + 1] = {last[1], pos, new}
  else
    last[2] = last[2] + 1
  end
  return last
end

local p = require'lua-uni-parse'
local codepoint_list = p.codepoint * (' ' * p.codepoint)^0/utf8.char

local results = p.parse_file('NormalizationTest', lpeg.Cf(
    lpeg.Ct(lpeg.Cc(0) * lpeg.Cc(0))
  * ('@' * p.ignore_line + p.eol
    + lpeg.Cg(lpeg.Cp() * (p.fields(codepoint_list,
                                    codepoint_list,
                                    codepoint_list,
                                    codepoint_list,
                                    codepoint_list * p.sep) / dostep)))^0
, jointests) * -1)
if not results then
  error'Reading tests failed'
end
for k=3,#results do
  texio.write_nl(string.format('Failure at test %i, offset %i, %s', results[k][1], results[k][2], require'inspect'(results[k][3])))
end
texio.write_nl(string.format("%i/%i tests succeeded!", results[2], results[1]))
-- os.exit(results[1] == results[2] and 0 or 1)
