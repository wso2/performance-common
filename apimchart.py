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
import seaborn as sns
import matplotlib.pyplot as plt
import matplotlib.ticker as tkr
import re

def save_multi_columns_categorical_charts(df, chart, sleep_time, columns, y, hue, title, single_statistic=False, single_statistic_name=None, kind='point'):
    print("Creating " + chart + " charts for " + str(sleep_time) + "ms backend delay")
    fig, ax = plt.subplots()
    df_results = df.loc[df['Sleep Time (ms)'] == sleep_time]
    all_columns=['Message Size (Bytes)','Concurrent Users']
    all_columns.extend(columns)
    df_results=df_results[all_columns]
    df_results = df_results.set_index(['Message Size (Bytes)', 'Concurrent Users']).stack().reset_index().rename(columns={'level_2': hue, 0: y})
    g = sns.factorplot(x="Concurrent Users", y=y,
        hue=hue, col="Message Size (Bytes)",
        data=df_results, kind=kind,
        size=5, aspect=1, col_wrap=2 ,legend=False);
    for ax in g.axes.flatten():
        ax.yaxis.set_major_formatter(
            tkr.FuncFormatter(lambda y, p: "{:,}".format(y)))
    plt.subplots_adjust(top=0.9, left=0.1)
    g.fig.suptitle(title)
    plt.legend(frameon=True)
    if single_statistic:
        # Get legend and remove column name from legend
        for ax in g.axes.flat:
            leg = ax.get_legend()
            if not leg is None: break
        for text in leg.texts:
            text.set_text(re.sub(re.escape(single_statistic_name) + r'\s*-\s*', '', text.get_text()))
    plt.savefig(chart + "_" + str(sleep_time) + "ms.png")
    plt.clf()
    plt.close(fig)