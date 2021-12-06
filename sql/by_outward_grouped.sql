SELECT * FROM layouts
GROUP BY outward
ORDER BY outward, same_finger_rp, jumps, score DESC;
