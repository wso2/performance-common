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
    df_charts.sort_index().to_csv("all-comparison-plots/charts.csv")


atexit.register(save_charts_details)


def save_multi_columns_categorical_charts(df, chart, columns, y, title,col,isSingleComparison, single_statistic=False,kind='point'):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    fig, ax = plt.subplots()

    if isSingleComparison:
        all_columns = [col,'Message Size (Bytes)', 'Concurrent Users','Scenario Name']
    else:
        all_columns = [col, 'Concurrent Users', 'Scenario Name']

    all_columns.extend(columns)
    df_results = df[all_columns]

    if single_statistic:
        if isSingleComparison:
            df_results['hue'] = df_results['Message Size (Bytes)'] + ' - ' + df_results['Scenario Name']
        else:
            df_results.rename(columns = {'Scenario Name':'hue'}, inplace=True)
    else:
        if isSingleComparison:
            df_results = df_results.melt(id_vars=['Scenario Name', 'Concurrent Users','Message Size (Bytes)',col],value_vars=columns,value_name=y)
            df_results['hue'] = df_results.variable + ' - ' + df_results['Scenario Name'] + df_results['Message Size (Bytes)']
        else:
            df_results = df_results.melt(id_vars=['Scenario Name', 'Concurrent Users',col],
                                         value_vars=columns, value_name=y)
            df_results['hue'] = df_results.variable + ' - ' + df_results['Scenario Name']


    graph = sns.factorplot(x="Concurrent Users", y=y,
                           hue='hue', col=col,
                           data=df_results, kind=kind,
                           size=7, aspect=1, col_wrap=2, legend=False)

    plt.subplots_adjust(top=0.9, left=0.1)
    graph.fig.suptitle(title)
    plt.legend(bbox_to_anchor=(1.05, 1), loc=2, borderaxespad=0.,title="Response Time Summary")
    graph.savefig("all-comparison-plots/"+filename)
    plt.clf()
    plt.cla()
    plt.close(fig)
    add_chart_details(title, filename)


def save_lmplot(df, chart, x, y, title, hue=None, xlabel=None, ylabel=None):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    add_chart_details(title, filename)
    fig, ax = plt.subplots()
    g = sns.lmplot(data=df, x=x, y=y, hue=hue, size=6)
    for ax in g.axes.flatten():
        ax.yaxis.set_major_formatter(
            tkr.FuncFormatter(lambda y_value, p: "{:,}".format(y_value)))
    plt.subplots_adjust(top=0.9, left=0.18)
    g.set_axis_labels(xlabel, ylabel)
    g.set(ylim=(0, None))
    g.fig.suptitle(title)
    plt.savefig("all-comparison-plots/"+filename)
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
    sns_plot.set(xlabel=xlabel, ylabel=ylabel)
    plt.legend(frameon=True)
    plt.savefig("all-comparison-plots/"+filename)
    plt.clf()
    plt.close(fig)


def save_bar_plot(df, chart, columns, y, title):
    filename = chart + ".png"
    print("Creating chart: " + title + ", File name: " + filename)
    fig, ax = plt.subplots()
    fig.set_size_inches(20, 8)
    all_columns = ['Scenario Name','Concurrent Users']
    all_columns.extend(columns)
    df_results = df[all_columns]
    df_results = df_results.melt(id_vars=['Scenario Name', 'Concurrent Users'],value_vars=columns,value_name=y)
    df_results['hue'] = df_results.variable + ' - ' + df_results['Scenario Name']
    graph = sns.barplot(x="Concurrent Users", y=y, hue='hue', data=df_results)
    plt.suptitle(title)
    plt.legend(bbox_to_anchor=(1.05, 1), loc=2, borderaxespad=0.,title="Response Time Summary")
    plt.subplots_adjust(top=0.9, left=0.1, right=0.7)
    plt.savefig("all-comparison-plots/"+filename)
    plt.clf()
    plt.close(fig)
    add_chart_details(title, filename)



