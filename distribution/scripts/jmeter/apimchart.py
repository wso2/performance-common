# Copyright 2017 WSO2 Inc. (http://wso2.org)
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ----------------------------------------------------------------------------
# Common python module to save charts
# ----------------------------------------------------------------------------
import atexit
import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import pandas as pd
import re
import seaborn as sns

df_charts = None


def format_bytes(b):
    if b >= 1024 and b % 1024 == 0:
        return str(b // 1024) + 'KiB'
    return str(b) + 'B'


def format_time(t):
    if t >= 1000 and t % 1000 == 0:
        return str(t // 1000) + 's'
    return str(t) + 'ms'


def add_chart_details(title, filename):
    global df_charts
    df = pd.DataFrame.from_records([{'Title': title, 'Filename': filename}], index='Filename')
    if df_charts is None:
        df_charts = df
    else:
        df_charts = df_charts.append(df)


def save_charts_details():
    print("Saving charts' details to charts.csv")
    df_charts.sort_index().to_csv("charts.csv")


atexit.register(save_charts_details)


def save_multi_columns_categorical_charts(df, chart, columns, y, hue, title, single_statistic=False,
                                          single_statistic_name=None, kind='point', col='Message Size (Bytes)'):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    add_chart_details(title, filename)
    fig, ax = plt.subplots()
    all_columns = [col, 'Concurrent Users']
    all_columns.extend(columns)
    df_results = df[all_columns]
    df_results = df_results.set_index([col, 'Concurrent Users']).stack().reset_index().rename(
        columns={'level_2': hue, 0: y})
    g = sns.factorplot(x="Concurrent Users", y=y,
                       hue=hue, col=col,
                       data=df_results, kind=kind,
                       size=5, aspect=1, col_wrap=2, legend=False)
    for ax in g.axes.flatten():
        ax.yaxis.set_major_formatter(
            tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    plt.subplots_adjust(top=0.9, left=0.1)
    g.fig.suptitle(title)
    plt.legend(frameon=True)
    if single_statistic:
        leg = None
        # Get legend and remove column name from legend
        for ax in g.axes.flat:
            leg = ax.get_legend()
            if leg is not None:
                break
        if leg is not None:
            for text in leg.texts:
                text.set_text(re.sub(re.escape(single_statistic_name) + r'\s*-\s*', '', text.get_text()))
    plt.savefig(filename)
    plt.clf()
    plt.cla()
    plt.close(fig)


def save_lmplot(df, chart, x, y, title, hue=None, xlabel=None, ylabel=None):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    add_chart_details(title, filename)
    fig, ax = plt.subplots()
    # fig.set_size_inches(10, 8)
    g = sns.lmplot(data=df, x=x, y=y, hue=hue, size=6)
    for ax in g.axes.flatten():
        ax.yaxis.set_major_formatter(
            tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    plt.subplots_adjust(top=0.9, left=0.18)
    if xlabel is None:
        xlabel = x
    if ylabel is None:
        ylabel = y
    g.set_axis_labels(xlabel, ylabel)
    g.set(ylim=(0, None))
    g.fig.suptitle(title)
    plt.savefig(filename)
    plt.clf()
    plt.cla()
    plt.close(fig)


def save_point_plot(df, chart, x, y, title, hue=None, xlabel=None, ylabel=None):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    add_chart_details(title, filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(8, 4)
    sns_plot = sns.pointplot(x=x, y=y, hue=hue, data=df, ci=None, dodge=True)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    plt.suptitle(title)
    if xlabel is None:
        xlabel = x
    if ylabel is None:
        ylabel = y
    sns_plot.set(xlabel=xlabel, ylabel=ylabel)
    plt.legend(frameon=True)
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)


def save_bar_plot(df, chart, x, y, title, hue=None, xlabel=None, ylabel=None):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    add_chart_details(title, filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(8, 4)
    sns_plot = sns.barplot(x=x, y=y, hue=hue, data=df, ci=None)
    ax.yaxis.set_major_formatter(tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    plt.suptitle(title)
    if xlabel is None:
        xlabel = x
    if ylabel is None:
        ylabel = y
    sns_plot.set(xlabel=xlabel, ylabel=ylabel)
    plt.legend(frameon=True)
    plt.savefig(filename)
    plt.clf()
    plt.close(fig)
