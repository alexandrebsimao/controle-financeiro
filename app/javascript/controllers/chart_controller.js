import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
    static values = {
    labels: Array,
    data: Array,
    type: String,
    income: Array,
    expenses: Array,
    investments: Array,
    balance: Array,
    rates: Array,
    datasets: Array,
    colors: Array,
    stacked: Boolean,
    unit: String
  }

  connect() {
    if (!this.labelsValue || this.labelsValue.length === 0) {
      return
    }

    const ctx = this.element.getContext("2d")
    if (!ctx) {
      return
    }

    // Chart.js is loaded globally via script tag in head
    if (typeof Chart === "undefined") {
      setTimeout(() => this.connect(), 100)
      return
    }

    try {
      if (this.chart) {
        this.chart.destroy()
      }

      const existingChart = Chart.getChart(this.element)
      if (existingChart) {
        existingChart.destroy()
      }

      const chartConfig = this.buildChartConfig(ctx)
      if (chartConfig) {
        this.chart = new Chart(ctx, chartConfig)
      }
    } catch (error) {
      console.error("Error initializing chart:", error)
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
  }

  buildChartConfig(ctx) {
    const type = this.typeValue || "doughnut"

    // 1. Gráfico customizado com datasets dinâmicos (ex: Categorias empilhadas ou Comprometimento de Renda)
    if (this.hasDatasetsValue && this.datasetsValue.length > 0) {
      return this.buildDynamicDatasetsConfig()
    }

    // 2. Gráfico Combo de Taxa de Poupança (Receitas x Despesas em Barras + Taxa em Linha)
    if (type === "savings-rate") {
      return this.buildSavingsRateConfig()
    }

    // 3. Gráfico de Fluxo de Caixa Diário (Linha de saldo dia a dia com preenchimento)
    if (type === "daily-cash-flow") {
      return this.buildDailyCashFlowConfig(ctx)
    }

    // 4. Gráfico Linha Padrão (Receitas, Despesas e Saldo Projetado do Dashboard)
    if (type === "line" && this.hasIncomeValue && this.hasExpensesValue) {
      return this.buildStandardLineConfig()
    }

    // 5. Gráfico de Rosca / Pizza / Barras Simples
    return this.buildStandardDoughnutOrBarConfig()
  }

  // ============================================
  // CONFIGURAÇÕES ESPECÍFICAS DE CADA GRÁFICO
  // ============================================

  buildDynamicDatasetsConfig() {
    const isStacked = this.stackedValue || false

    const datasets = this.datasetsValue.map(ds => {
      const parsedData = (ds.data || []).map(v => {
        const n = parseFloat(v)
        return isNaN(n) ? 0 : n
      })

      return {
        label: ds.name || ds.label,
        type: ds.type || (this.typeValue === "bar" ? "bar" : "line"),
        data: parsedData,
        backgroundColor: ds.backgroundColor || ds.color || "#6366f1",
        borderColor: ds.borderColor || ds.color || "#6366f1",
        borderWidth: ds.borderWidth !== undefined ? ds.borderWidth : (ds.type === "line" ? 2.5 : 1),
        borderRadius: ds.borderRadius !== undefined ? ds.borderRadius : (isStacked ? 4 : 6),
        fill: ds.fill !== undefined ? ds.fill : false,
        tension: ds.tension !== undefined ? ds.tension : 0.3,
        stack: (isStacked && ds.type !== "line") ? (ds.stack || "stack1") : undefined,
        yAxisID: ds.yAxisID || "y"
      }
    })

    return {
      type: this.typeValue === "line" ? "line" : "bar",
      data: {
        labels: this.labelsValue,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: {
            position: "top",
            labels: {
              boxWidth: 12,
              padding: 14,
              font: { size: 12, weight: 600 }
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const val = context.parsed.y
                return ` ${context.dataset.label}: ${this.formatCurrency(val)}`
              }
            }
          }
        },
        scales: {
          x: {
            stacked: isStacked,
            grid: { display: false }
          },
          y: {
            stacked: isStacked,
            beginAtZero: true,
            ticks: {
              callback: (val) => this.formatCurrency(val)
            }
          }
        }
      }
    }
  }

  buildSavingsRateConfig() {
    const incomes = (this.incomeValue || []).map(v => parseFloat(v) || 0)
    const expenses = (this.expensesValue || []).map(v => parseFloat(v) || 0)
    const rates = (this.ratesValue || []).map(v => parseFloat(v) || 0)
    const investments = (this.investmentsValue || []).map(v => parseFloat(v) || 0)

    const datasets = [
      {
        type: "line",
        label: "Taxa de Poupança (%)",
        data: rates,
        borderColor: "#8b5cf6",
        backgroundColor: "rgba(139, 92, 246, 0.1)",
        borderWidth: 3,
        pointBackgroundColor: "#8b5cf6",
        pointBorderColor: "#fff",
        pointBorderWidth: 2,
        pointRadius: 4,
        tension: 0.3,
        yAxisID: "y1"
      },
      {
        type: "bar",
        label: "Receitas",
        data: incomes,
        backgroundColor: "rgba(16, 185, 129, 0.85)",
        borderRadius: 6,
        yAxisID: "y"
      },
      {
        type: "bar",
        label: "Despesas",
        data: expenses,
        backgroundColor: "rgba(244, 63, 94, 0.85)",
        borderRadius: 6,
        yAxisID: "y"
      }
    ]

    if (investments.some(v => v > 0)) {
      datasets.push({
        type: "bar",
        label: "Investimentos (Aportes)",
        data: investments,
        backgroundColor: "rgba(79, 70, 229, 0.85)",
        borderRadius: 6,
        yAxisID: "y"
      })
    }

    return {
      type: "bar",
      data: {
        labels: this.labelsValue,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: {
            position: "top",
            labels: {
              boxWidth: 12,
              padding: 14,
              font: { size: 12, weight: 600 }
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                if (context.dataset.yAxisID === "y1") {
                  return ` ${context.dataset.label}: ${context.parsed.y.toFixed(1)}%`
                }
                return ` ${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}`
              }
            }
          }
        },
        scales: {
          x: {
            grid: { display: false }
          },
          y: {
            beginAtZero: true,
            position: "left",
            ticks: {
              callback: (val) => this.formatCurrency(val)
            }
          },
          y1: {
            beginAtZero: true,
            position: "right",
            grid: { drawOnChartArea: false },
            ticks: {
              callback: (val) => `${val}%`
            }
          }
        }
      }
    }
  }

  buildDailyCashFlowConfig(ctx) {
    const balances = (this.balanceValue || []).map(v => parseFloat(v) || 0)

    // Gradiente bonito
    const gradient = ctx.createLinearGradient(0, 0, 0, 300)
    gradient.addColorStop(0, "rgba(79, 70, 229, 0.25)")
    gradient.addColorStop(1, "rgba(79, 70, 229, 0.0)")

    return {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            label: "Saldo Projetado Dia a Dia",
            data: balances,
            borderColor: "#4f46e5",
            borderWidth: 2.5,
            backgroundColor: gradient,
            fill: true,
            tension: 0.25,
            pointRadius: 0,
            pointHoverRadius: 5,
            pointHoverBackgroundColor: "#4f46e5",
            pointHoverBorderColor: "#fff",
            pointHoverBorderWidth: 2
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          mode: "index",
          intersect: false
        },
        plugins: {
          legend: { display: false },
          tooltip: {
            callbacks: {
              label: (context) => ` Saldo: ${this.formatCurrency(context.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            grid: { display: false },
            ticks: {
              maxTicksLimit: 12
            }
          },
          y: {
            ticks: {
              callback: (val) => this.formatCurrency(val)
            }
          }
        }
      }
    }
  }

  buildStandardLineConfig() {
    const incomeData = (this.incomeValue || []).map(v => parseFloat(v) || 0)
    const expensesData = (this.expensesValue || []).map(v => parseFloat(v) || 0)

    const datasets = [
      {
        label: "Receitas",
        data: incomeData,
        borderColor: "#10b981",
        backgroundColor: "rgba(16, 185, 129, 0.08)",
        borderWidth: 2.5,
        fill: true,
        tension: 0.3,
        pointRadius: 4,
        pointBackgroundColor: "#10b981",
        pointBorderColor: "#fff",
        pointBorderWidth: 2
      },
      {
        label: "Despesas",
        data: expensesData,
        borderColor: "#f43f5e",
        backgroundColor: "rgba(244, 63, 94, 0.08)",
        borderWidth: 2.5,
        fill: true,
        tension: 0.3,
        pointRadius: 4,
        pointBackgroundColor: "#f43f5e",
        pointBorderColor: "#fff",
        pointBorderWidth: 2
      }
    ]

    if (this.hasBalanceValue) {
      const balanceData = (this.balanceValue || []).map(v => parseFloat(v) || 0)
      datasets.push({
        label: "Saldo Projetado",
        data: balanceData,
        borderColor: "#6366f1",
        backgroundColor: "transparent",
        borderWidth: 2.5,
        borderDash: [4, 4],
        fill: false,
        tension: 0.25,
        pointRadius: 3,
        pointBackgroundColor: "#6366f1",
        pointBorderColor: "#fff",
        pointBorderWidth: 2
      })
    }

    return {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        interaction: {
          intersect: false,
          mode: "index"
        },
        plugins: {
          legend: {
            position: "top",
            labels: {
              padding: 14,
              font: { size: 12, weight: 600 }
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => ` ${context.dataset.label}: ${this.formatCurrency(context.parsed.y)}`
            }
          }
        },
        scales: {
          x: { grid: { display: false } },
          y: {
            beginAtZero: true,
            ticks: {
              callback: (val) => this.formatCurrency(val)
            }
          }
        }
      }
    }
  }

  buildStandardDoughnutOrBarConfig() {
    if (!this.dataValue || this.dataValue.length === 0) {
      return null
    }

    const numericData = this.dataValue.map(v => parseFloat(v) || 0)
    const colors = this.getColors()

    return {
      type: this.typeValue || "doughnut",
      data: {
        labels: this.labelsValue,
        datasets: [
          {
            data: numericData,
            backgroundColor: colors.slice(0, numericData.length),
            borderColor: "#fff",
            borderWidth: 2,
            borderRadius: 4
          }
        ]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              boxWidth: 12,
              padding: 12,
              font: { size: 12 }
            }
          },
          tooltip: {
            callbacks: {
              label: (context) => {
                const val = context.parsed || context.raw
                const unit = this.unitValue || "currency"
                if (unit === "percent") {
                  return ` ${context.label}: ${val.toFixed(1)}%`
                }
                return ` ${context.label}: ${this.formatCurrency(val)}`
              }
            }
          }
        }
      }
    }
  }

  formatCurrency(value) {
    if (isNaN(value)) return "R$ 0,00"
    return "R$ " + value.toLocaleString("pt-BR", { minimumFractionDigits: 2, maximumFractionDigits: 2 })
  }

  getColors() {
    if (this.hasColorsValue && this.colorsValue.length > 0) {
      return this.colorsValue
    }

    return [
      "#4f46e5", // indigo
      "#10b981", // emerald
      "#f43f5e", // rose
      "#f59e0b", // amber
      "#8b5cf6", // purple
      "#06b6d4", // cyan
      "#ec4899", // pink
      "#14b8a6", // teal
      "#f97316", // orange
      "#64748b"  // slate
    ]
  }
}
