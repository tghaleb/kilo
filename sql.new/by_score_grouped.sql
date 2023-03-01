SELECT * FROM layouts
GROUP BY score
ORDER BY score DESC, outward, jumps, positional_effort, alternation DESC;

