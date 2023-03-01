SELECT * FROM layouts
GROUP BY positional_effort
ORDER BY positional_effort, score DESC;
