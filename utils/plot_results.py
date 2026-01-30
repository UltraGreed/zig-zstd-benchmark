from itertools import cycle, batched

import pandas as pd
from bokeh.plotting import figure, show
from bokeh.palettes import Bright7 as palette  # noqa
from bokeh.layouts import gridplot


colors = cycle(palette)
def plot_csv(path):
    df = pd.read_csv(path)

    plots = []
    for file, file_grouped in df.groupby('File'):
        p = figure(
            resizable=True,
            width=600,
            height=400,
            x_axis_label='Compression level',
            y_axis_label='Average time (s)',
        )
        for lang, lang_grouped in file_grouped.groupby('Language'):
            for runs, runs_grouped in lang_grouped.groupby('N runs'):
                xs = runs_grouped['Compression level']
                ys = runs_grouped['Total time'] / runs_grouped['N runs']
                p.line(xs, ys, line_width=2, legend_label=f'{file}: {lang}, avg of {runs}',
                       color=next(colors))
                p.scatter(xs, ys, color='black')

        p.legend.click_policy = 'hide'
        plots.append(p)
    return plots

plots = plot_csv('out/runs.csv')

show(gridplot(batched(plots, 2)))  # type: ignore
