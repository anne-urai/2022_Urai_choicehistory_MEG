
function prettierTopoCTF275(ax)

if ~exist('ax', 'var'), ax = gca; end

% make the outlines thinner
lineObj = findobj(ax, 'type', 'line');
for l = 1:length(lineObj),
    if get(lineObj(l), 'LineWidth') > 0.5,
        set(lineObj(l), 'LineWidth', 0.15);
    end
    
    % recolor the head outline
    if strcmp(get(lineObj(l), 'marker'), 'none'),
        set(lineObj(l), 'Color', [0.3 0.3 0.3]);
    end
    
    % remove contour
    if strcmp(get(lineObj(l), 'LineStyle'), ':'),
        set(lineObj(l), 'LineStyle', 'none');
    end
end

% make sure the highlighted channels go on top
highlights = findobj(ax, 'Color', 'k');
uistack(highlights, 'top');

end