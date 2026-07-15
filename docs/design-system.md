# Finance AI Design System

## Direction

Finance AI uses a restrained galaxy dark theme: deep indigo background, elevated plum surfaces and a violet primary action. Financial states are always communicated by label, icon and color.

## Tokens

| Token | Purpose |
| --- | --- |
| `AppColors.brand` | Primary actions and selected navigation |
| `AppColors.positive` | Income and positive results |
| `AppColors.negative` | Expenses and negative results |
| `AppColors.crypto` | Cryptocurrency context |
| `AppColors.surfaceElevated` | Cards, dialogs and secondary surfaces |
| `AppSpacing` | 4, 8, 16, 24, 32 and 48px rhythm |
| `AppRadius` | 10, 14, 22 and 30px radii |
| `AppAnimations` | 160ms, 220ms and 320ms transitions |

## Components

The app shell is composed of sidebar, topbar and constrained main content. Reusable UI includes `PageHeader`, `Panel`, `FinancialValue`, metric cards, empty states, forms and charts. Financial values use tabular figures and obey the global privacy toggle.

## Responsive behavior

Desktop navigation appears at 1200px and above. Smaller widths use the drawer. Main content is constrained to 1440px, preventing ultrawide layouts from becoming unreadable.
