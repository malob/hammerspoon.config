--- === hs.fuzzy ===
---
--- Functions for [fuzzy string searching](https://en.wikipedia.org/wiki/Approximate_string_matching), including utility functions for finding the [edit distance](https://en.wikipedia.org/wiki/String_metric)(also known as string metric) between two strings.
---
--- This module is heavily based on Alexander "Apickx" Pickering's [Fuzzel](https://cogarr.net/source/cgit.cgi/fuzzel/).

local fuzzy = {}

local stringLen, stringByte, stringSub = string.len, string.byte, string.sub
local tableUnpack, tableSort, tableInsert = table.unpack, table.sort, table.insert
local mathMin, assert, pairs = math.min, assert, pairs


-- Helper function for calculating (Demerau-)Levenshtein distance
local function genericDistance(str1, str2, addCost, subCost, delCost, trnCost)
  --Length of each string
  local str1Len, str2Len = stringLen(str1), stringLen(str2)

  --Create a 0 matrix the size of len(str1) x len(str2)
  local dyntbl = {}
  for i = 0, str1Len do
    dyntbl[i] = {}
    for j = 0, str2Len do
      dyntbl[i][j] = 0
    end
  end

  --Initalize the matrix
  for i = 1, str1Len do
    dyntbl[i][0] = i
  end
  for j = 1, str2Len do
    dyntbl[0][j] = j
  end

  --And build up the matrix based on costs-so-far
  for j = 1, str2Len do
    for i = 1, str1Len do
      local c1, c2 = stringByte(str1, i),stringByte(str2, j)
      dyntbl[i][j] = mathMin(
        dyntbl[i-1][j] + delCost, --deletion
        dyntbl[i][j-1] + addCost, --insertion
        dyntbl[i-1][j-1] + (c1 == c2 and 0 or subCost) --substituion
      )
      if trnCost and i > 1 and j > 1 and c1 == stringByte(str2, j-1) and stringByte(str1, i-1) == c2 then
        dyntbl[i][j] = mathMin(dyntbl[i][j],
          dyntbl[i-2][j-2] + (c1 == c2 and 0 or trnCost)) --transposition
      end
    end
  end

  return dyntbl[str1Len][str2Len]
end
--- hs.fuzzy.LevenshteinDistance(str1, str2[, addCost, subCost, delCost]) -> number
--- Function
--- Uses Levenshtein distance to find the edit distance between two strings.
--- The Levenshtein distance is the minimum number of insertions, deletions, and substitutions that are needed to turn one string into another. This function allows custom costs for insertions, substitutions, and deletions. (The default costs are 1.)
---
--- Parameters:
--- * str1 (String)
--- * str2 (String)
--- * (Optional) addCost (Number) - The cost of inserting one character. Default is 1.
--- * (Optional) subCost (Number) - The cost of substituting one character for another. Default is 1.
--- * (Optional) delCost (Number) - The cost of deleting one character. Default is 1.
---
--- Returns:
--- * (Number) The edit distance between the two strings.
fuzzy.LevenshteinDistance = function(str1, str2, addCost, subCost, delCost)
  return genericDistance(str1, str2, addCost or 1, subCost or 1, delCost or 1)
end

--- hs.fuzzy.ld
--- Function
--- Alias for `hs.fuzzy.LevenshteinDistance`.
fuzzy.ld = fuzzy.LevenshteinDistance

--- hs.fuzzy.LevenshteinRatio(str1, str2) -> number
--- Function
--- Finds the edit ratio between two strings using Levenshtein distance.
---
--- Parameters:
--- * str1 (String) - The first string, and the string to use for the ratio.
--- * str2 (String) - The second string.
---
--- Returns:
--- * (Number) The edit distance between the two strings divided by the length of the first string.
fuzzy.LevenshteinRatio = function(str1, str2)
  return fuzzy.LevenshteinDistance(str1, str2) / stringLen(str1)
end

--- hs.fuzzy.lr
--- Function
--- Alias for `hs.fuzzy.LevenshteinRatio`.
fuzzy.lr = fuzzy.LevenshteinRatio

--- hs.fuzzy.DamerauLevenshteinDistance(str1, str2[, addCost, subCost, delCost, trnCost]) -> number
--- Function
--- Uses the Damerau-Levenshtein distance to find the edit distance between two strings.
--- The Damerau-Levenshtein distance is the minimum number of insertions, substitutions, deletions, or transpositions that are neeed to turn one string into another. This function allows custom costs for additions, substitutions, deletions, and transpositions. (The default costs are 1.)
---
--- Parameters:
--- * str1 (String)
--- * str2 (String)
--- * (Optional) addCost (Number) - The cost of inserting one character. Default is 1.
--- * (Optional) subCost (Number) - The cost of substituting one character for another. Default is 1.
--- * (Optional) delCost (Number) - The cost of deleting one character. Default is 1.
--- * (Optional) trnCost (Number) - The cost of transposing two adjacent characters. Default is 1.
---
--- Returns:
--- * (Number) The edit distance between the two strings.
fuzzy.DamerauLevenshteinDistance = function(str1, str2, addCost, subCost, delCost, trnCost)
  return genericDistance(str1, str2, addCost or 1, subCost or 1, delCost or 1, trnCost or 1)
end

--- hs.fuzzy.dld
--- Function
--- Alias for `hs.fuzzy.DamerauLevenshteinDistance`.
fuzzy.dld = fuzzy.DamerauLevenshteinDistance

--- hs.fuzzy.DamerauLevenshteinRatio(str1, str2) -> number
--- Function
--- Finds the edit ratio between two strings using Demerau-Levenshtein distance.
---
--- Parameters:
--- * str1 (String) - The first string, and the string to use for the ratio.
--- * str2 (String) - The second string.
---
--- Returns:
--- * (Number) The edit distance between the two strings divided by the length of the first string.
fuzzy.DamerauLevenshteinRatio = function(str1, str2)
  return fuzzy.DamerauLevenshteinDistance(str1, str2) / stringLen(str1)
end

--- hs.fuzzy.dlr
--- Function
--- Alias for `hs.fuzzy.DamerauLevenshteinRatio`
fuzzy.dlr = fuzzy.DamerauLevenshteinRatio

--- hs.fuzzy.HammingDistance(str1, str2) -> number
--- Function
--- Uses the Hamming distance to find the edit distance between two strings.
--- The Hamming distance is the minimum number substitutions that are neeed to turn one string into another. Since only substitutions can be used, Hamming distance can only be calculated between two strings of equal length.
---
--- Parameters:
--- * str1 (String)
--- * str2 (String)
---
--- Returns:
--- * (Number) The edit distance between the two strings.
fuzzy.HammingDistance = function(str1, str2)
  local len, dist = stringLen(str1),0
  assert(len == stringLen(str2), "Hamming distance cannot be calculated on two strings of different lengths.")
  for i = 1, len do
    dist = dist + ((stringByte(str1, i) ~= stringByte(str2, i)) and 1 or 0)
  end
  return dist
end

--- hs.fuzzy.hd
--- Function
--- Alias for `hs.fuzzy.HammingDistance`.
fuzzy.hd = fuzzy.HammingDistance

--- hs.fuzzy.HammingRatio(str1, str2) -> number
--- Function
--- Finds the edit ratio between two strings using Hamming distance.
---
--- Parameters:
--- * str1 (String) - The first string, and the string to use for the ratio.
--- * str2 (String) - The second string.
---
--- Returns:
--- * (Number) The edit distance between the two strings divided by the length of the first string.
fuzzy.HammingRatio = function(str1, str2)
  return fuzzy.HammingDistance(str1, str2) / stringLen(str1)
end

--- hs.fuzzy.hr
--- Function
--- Alias for `hs.fuzzy.HammingRatio`
fuzzy.hr = fuzzy.HammingRatio

-- Local helper function to find the string from in array `listOfStrings` with the shortest distance to the string `str` according to `metricFunc`.
local function fuzzySearch(str, listOfStrings, metricFunc)
  local minDist, minDistIdx = nil, nil
  for i = 1, #listOfStrings do
    local distance = metricFunc(listOfStrings[i], str)
    if (not minDist) or distance < minDist then
      minDist, minDistIdx = distance, i
    end
  end
  return listOfStrings[minDistIdx], minDist
end
--- hs.fuzzy.find(str, listOfStrings[, metric]) -> string, number
--- Function
--- Given a string `str`, find the best match in a list of strings `listOfStrings`, according to a string metric (ratio) `metric`. The default string metric (ratio) is `DamerauLevenshteinDistance`.
---
--- Parameters:
--- * str (String)
--- * listOfStrings (List) - A list of strings.
--- * (Optional) metric (String) - The string metric used to compare `str` with each string in `listOfStrings`. Can be any of the distances or ratios (or their aliases) in this module. Default is `DamerauLevenshteinDistance`.
---
--- Returns:
--- * (String) The string in `listOfStrings` with the smallest edit distance (ratio) `str` according to `metric`.
--- * (Number) The distance or ratio between `str` and the best match in `listOfStrings`.
fuzzy.find = function(str, listOfStrings, metric)
  return tableUnpack{fuzzySearch(str, listOfStrings, fuzzy[metric] or fuzzy.DamerauLevenshteinDistance)}
end

-- Local helper function that returns a new list containing strings in `listOfStrings` sorted by `metricFunc` to the string `str`.
local function fuzzySort(str, listOfStrings, metricFunc, short)
  --Roughly sort everything by it's distance to the string
  local unSorted, sorted, outList, strLen = {}, {}, {}, stringLen(str)
  for i = 1, #listOfStrings do
    local sStr = short and stringSub(listOfStrings[i], 1, strLen) or listOfStrings[i]
    local dist = metricFunc(str, sStr)
    if unSorted[dist] == nil then
      unSorted[dist] = {}
      tableInsert(sorted, dist)
    end
    tableInsert(unSorted[dist], listOfStrings[i])
  end

  --Actually sort them into something can can be iterated with ipairs
  tableSort(sorted)

  --Then build our output table
  for i = 1, #sorted do
    for _, j in pairs(unSorted[sorted[i]]) do
      tableInsert(outList, j)
    end
  end
  return outList
end
--- hs.fuzzy.sort(str, listOfStrings[, metric]) -> list (of strings)
--- Function
--- Given a string `str`, sorts the list of strings `listOfStrings`, according to a string metric (ratio) `metric`. The default string metric (ratio) is `DamerauLevenshteinDistance`.
---
--- Parameters:
--- * str (String)
--- * listOfStrings (List) - A list of strings to sort.
--- * (Optional) metric (String) - The string metric (ratio) used to compare `str` with each string in `listOfStrings`. Can be any of the distances or ratios (or their aliases) in this module. Default is `DamerauLevenshteinDistance`.
---
--- Returns:
--- * (List) An new list containing the strings in `srtList` sorted by the distance or ratio when compared with `str` using `metric`.
fuzzy.sort = function(str, listOfStrings, metric)
  return fuzzySort(str, listOfStrings, fuzzy[metric] or fuzzy.DamerauLevenshteinDistance, false)
end

--- hs.fuzzy.autocomplete(str, listOfStrings[, metric]) -> list (of strings)
--- Function
--- Just like `hs.fuzzy.sort`, given a string `str`, sorts the list of strings `listOfStrings`, according to a string metric (ratio) `metric`. The difference is that `hs.fuzzy.autocomplete` truncates each string in `listOfStrings` to the length of `str` before calculating the distance or ratio. The default string metric (ratio) is `DamerauLevenshteinDistance`.
---
--- Parameters:
--- * str (String)
--- * listOfStrings (List) - A list of strings to sort.
--- * (Optional) metric (String) - The string metric used to compare `str` with each truncated string in `listOfStrings`.  Can be any of the distances or ratios (or their aliases) in this module. Default is `DamerauLevenshteinDistance`.
---
--- Returns:
--- * (List) An new list containing the full strings from `srtList` sorted by the distance or ratio of their truncated versions when compared with `str` using `metric`.
fuzzy.autocomplete = function(str, listOfStrings, metric)
  return fuzzySort(str, listOfStrings, fuzzy[metric] or fuzzy.DamerauLevenshteinDistance, true)
end

return fuzzy
