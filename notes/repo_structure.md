# mockfactory 仓库模块关系图

这份文档用中文梳理 `mockfactory` 仓库的主要模块、依赖关系和典型数据流，方便快速理解“这个仓库各部分是怎么配合起来工作的”。

## 一句话概览

这是一个面向宇宙学大尺度结构模拟的 Python 工具库，核心流程是：

1. 在三维周期盒子中生成 Gaussian / lognormal mock。
2. 将连续密度场变成离散 catalog。
3. 施加 RSD、selection function、径向/角向 mask。
4. 将 box mock 变换成真实 survey 的 cut-sky mock。
5. 按需叠加 DESI 实验效应和 blinding。

## 总体模块关系图

```text
README / notebooks / example scripts
        |
        v
mockfactory/__init__.py
        |
        v
mockfactory/gaussian_mock.py
  BaseGaussianMock
        |
        +-----------------------------------------------+
        |                                               |
        v                                               v
mockfactory/eulerian_mock.py          mockfactory/lagrangian_mock.py
  EulerianLinearMock                     LagrangianLinearMock
        |                                               |
        +------- 生成 box 中的密度场 / 粒子 catalog -------+
                                 |
                                 v
                  mockfactory/make_survey.py
                     BoxCatalog / RandomBoxCatalog
                                 |
               +--> 可选: mockfactory/remap.py
               |         Cuboid remap
               |
               v
                survey geometry / isometry / masks
                     in make_survey.py
                                 |
                                 v
                  mockfactory/make_survey.py
                  CutskyCatalog / RandomCutskyCatalog
                                 |
               +-----------------+------------------+
               |                                    |
               v                                    v
         mockfactory/desi/                    mockfactory/blinding/
      DESI 专用实验效应                        catalog 盲化工具
```

这里的时序更准确一些：

- `gaussian_mock.py`、`eulerian_mock.py`、`lagrangian_mock.py` 负责先生成盒子里的场和粒子。
- 这些结果通常先进入 `make_survey.py` 定义的 `BoxCatalog` / `RandomBoxCatalog`。
- 在 box catalog 阶段，可以先选择是否通过 `remap.py` 做 `Cuboid remap`。
- 无论是否 remap，后面都会进入 `make_survey.py` 里的 `cutsky`、`isometry`、radial/angular masks 等 survey 几何操作。

## 仓库目录视图

```text
mockfactory/
├── mockfactory/
│   ├── __init__.py
│   ├── gaussian_mock.py
│   ├── eulerian_mock.py
│   ├── lagrangian_mock.py
│   ├── make_survey.py
│   ├── remap.py
│   ├── utils.py
│   ├── desi/
│   ├── blinding/
│   └── tests/
├── desi/
│   ├── from_box_to_desi_cutsky.py
│   └── ...
├── nb/
│   ├── basic_examples.ipynb
│   ├── remap_examples.ipynb
│   └── ...
├── README.md
└── pyproject.toml
```

## 主要模块职责

### 1. `mockfactory/__init__.py`

作用：

- 统一导出外部 API。
- 把常用类和函数集中暴露给用户。

用户通常会直接这样用：

```python
from mockfactory import LagrangianLinearMock, RandomBoxCatalog, DistanceToRedshift
```

这说明它本质上是整个包的“公共入口”。

### 2. `mockfactory/gaussian_mock.py`

作用：

- 是 Gaussian mock 生成的基础层。
- 定义 `BaseGaussianMock`。
- 负责构建 Fourier 空间密度场、管理 mesh、MPI 通信、随机种子等基础能力。

可以把它理解成：

“所有 mock 生成器共享的底座”

上层的 Eulerian / Lagrangian mock 都建立在这里。

### 3. `mockfactory/eulerian_mock.py`

作用：

- 定义 `EulerianLinearMock`。
- 在 Eulerian 框架下处理线性 bias 和 RSD。

特点：

- 更偏向直接在密度场层面操作。
- 适合把理论功率谱快速变成一个带 RSD 的 box density field / catalog。

### 4. `mockfactory/lagrangian_mock.py`

作用：

- 定义 `LagrangianLinearMock`。
- 用一阶 Lagrangian / Zeldovich 近似生成位移场和粒子位置。

特点：

- 会先构造位移场，再 Poisson 采样，再推动粒子位置。
- 更贴近“先有初始位移，再得到最终 catalog”的思路。

这是 README 和示例里最常出现的主力类之一。

### 5. `mockfactory/make_survey.py`

作用：

- 这是仓库最核心的 survey 几何层。
- 负责把盒子里的 mock 变成天球上的 cut-sky catalog。

内部大致分成几块：

- 几何变换：`EuclideanIsometry`
- box / cutsky 关系：`box_to_cutsky()`、`cutsky_to_box()`
- catalog 类：
  - `ParticleCatalog`
  - `BoxCatalog`
  - `CutskyCatalog`
  - `RandomBoxCatalog`
  - `RandomCutskyCatalog`
- 径向 mask：
  - `UniformRadialMask`
  - `TabulatedRadialMask`
- 角向 mask：
  - `UniformAngularMask`
  - `MangleAngularMask`
  - `HealpixAngularMask`
- 红移处理：
  - `DistanceToRedshift`
  - `RedshiftDensityInterpolator`
  - redshift smearing 相关类

如果把整个仓库比作流水线，`make_survey.py` 就是连接“盒子模拟”和“观测 catalog”的中间总装线。

### 6. `mockfactory/remap.py`

作用：

- 实现 cuboid remap。
- 把周期性立方盒子重映射成另一个长方体，同时尽量保持周期性。

核心类：

- `Cuboid`

适用场景：

- 原始 box 的长宽高不适合目标 survey 几何。
- 希望通过几何 remap 更高效地利用一个模拟盒子。

### 7. `mockfactory/utils.py`

作用：

- 放通用数学和坐标工具。

常见内容包括：

- `cartesian_to_sky`
- `sky_to_cartesian`
- `wrap_angle`
- `vector_projection`
- 若干概率分布辅助工具

这是一个基础支撑模块，被很多上层文件复用。

### 8. `mockfactory/desi/`

作用：

- 放 DESI 专用扩展。
- 把通用 mock 进一步加工成更接近 DESI 实验的数据产物。

主要能力：

- `footprint.py`：判断是否在 DESI footprint 中
- `redshift_smearing.py`：DESI tracer 的红移模糊
- `fiber_assignment.py`：fiber assignment 相关流程
- `brick_pixel_quantities.py`：brick pixel 属性查询

可以理解为：

“通用 mock 框架之上的 DESI 实验适配层”

### 9. `mockfactory/blinding/`

作用：

- 做 catalog-level blinding。
- 支持 AP blinding、RSD blinding、PNG blinding 等。

核心文件：

- `catalog.py`

核心对象：

- `CutskyCatalogBlinding`
- `get_cosmo_blind`

这个模块说明仓库不仅关心“生成 mock”，也关心真实分析流程中的“盲化需求”。

### 10. `mockfactory/tests/`

作用：

- 提供单元测试和功能性示例。
- 很适合作为“如何使用 API”的辅助文档。

建议优先看：

- `test_gaussian_mock.py`
- `test_make_survey.py`
- `blinding/tests/test_blinding.py`

### 11. 顶层 `desi/` 与 `nb/`

`desi/` 目录：

- 更偏脚本和工作流示例。
- 演示如何把 box mock 变成 DESI cutsky mock。

`nb/` 目录：

- notebook 示例。
- 适合快速理解基本流程和 remap 机制。

## 典型数据流

下面是这个仓库最典型的使用链路：

```text
理论功率谱 P(k)
   |
   v
Gaussian / Lagrangian / Eulerian mock
   |
   v
mesh density field
   |
   v
Poisson sampling
   |
   v
BoxCatalog / RandomBoxCatalog
   |
   +--> 可选: Cuboid remap
   |
   +--> 可选: RSD
   |
   v
cutsky geometry + radial/angular mask
   |
   v
CutskyCatalog / RandomCutskyCatalog
   |
   +--> 可选: DESI footprint / redshift smearing / fiber assignment
   |
   +--> 可选: blinding
   |
   v
最终输出 catalog
```

## 模块依赖的理解方式

可以把仓库分成 4 层：

### A. 基础工具层

- `utils.py`

负责坐标变换、数学辅助、日志等底层支持。

### B. 模拟生成层

- `gaussian_mock.py`
- `eulerian_mock.py`
- `lagrangian_mock.py`

负责从理论统计量生成 3D mock。

### C. survey 几何层

- `make_survey.py`
- `remap.py`

负责把 box mock 变成 survey catalog。

### D. 实验与分析层

- `desi/`
- `blinding/`

负责真实实验效应和分析流程适配。

## 如果你只想快速读懂仓库，推荐阅读顺序

### 路线 1：按使用流程理解

1. `README.md`
2. `mockfactory/__init__.py`
3. `mockfactory/lagrangian_mock.py`
4. `mockfactory/make_survey.py`
5. `mockfactory/remap.py`
6. `mockfactory/tests/test_make_survey.py`
7. `desi/from_box_to_desi_cutsky.py`

### 路线 2：按架构分层理解

1. `utils.py`
2. `gaussian_mock.py`
3. `eulerian_mock.py` 和 `lagrangian_mock.py`
4. `make_survey.py`
5. `remap.py`
6. `desi/`
7. `blinding/`

## 一句话总结

`mockfactory` 的核心不是单独某一个算法，而是一条完整链路：

“从 3D 理论功率谱出发，生成盒子中的 mock，再通过 survey 几何、mask、实验效应和盲化，把它加工成接近真实巡天分析输入的数据产品。”
