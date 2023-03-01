SELECT * FROM layouts
WHERE
((fingers0 + fingers9) < 2200) and
((fingers1 + fingers8) < 2600) and
((fingers3 + fingers6) < 4400)
ORDER BY text_direction DESC,
jumps + same_finger_rp + same_finger_im, jumps, same_finger_rp, same_finger_im, outward, positional_effort, score DESC;

