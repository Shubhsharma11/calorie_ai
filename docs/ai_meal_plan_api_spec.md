# AI Meal Plan — Backend API Spec (Mobile App Contract)

**Audience:** Backend team  
**App:** MyCaloriePal (Flutter)  
**Purpose:** Create / fetch weekly AI meal plan, support meal swaps via response data, log meals to diary  
**Auth:** `Authorization: Bearer <accessToken>`  
**Also sent:** `X-Timezone: Asia/Kolkata` (or device timezone)  
**Base path:** `/api/v1`

---

## 1. What the mobile app needs

| Feature | How it works today | Backend responsibility |
|---|---|---|
| Create / regenerate plan | `POST /nutrition/plan` | Generate macros + full weekly meals |
| Load plan | `GET /nutrition/plan` | Return saved plan (same shape as POST) |
| Meals per day (3 / 4 / 5) | Sent as `mealsPerDay` in POST body | Return exact slot count + labels below |
| Swap meal | **No swap endpoint yet** | Put 2–4 options in each meal’s `alternatives[]` |
| More options | Client uses other week meals of same slot | Prefer rich `alternatives[]` per meal |
| Don’t suggest | Client-only (not sent to API yet) | Optional future endpoint |
| Log planned meal | `POST /meals` | Normal meal create |

> **Swap today:** App does **not** call a swap API. It picks from `alternatives` (or same-slot meals in the week). If `alternatives` is empty, swap UX is weak.

---

## 2. Endpoints (current)

### 2.1 Create / regenerate AI plan
```
POST /api/v1/nutrition/plan
Content-Type: application/json
Authorization: Bearer <token>
```

### 2.2 Fetch AI plan
```
GET /api/v1/nutrition/plan
Authorization: Bearer <token>
```

### 2.3 Log a planned meal into diary
```
POST /api/v1/meals
Content-Type: application/json
Authorization: Bearer <token>
```

---

## 3. `POST /nutrition/plan` — Request body

App sends the **full user profile** (same shape as onboarding) so the plan can be generated even if onboarding was just saved.

### Example

```json
{
  "personalDetails": {
    "age": 28,
    "gender": "male",
    "heightCm": 175,
    "weight": 70,
    "weightUnit": "kg"
  },
  "goal": "gainWeight",
  "activityLevel": "moderatelyActive",
  "healthProblems": [
    {
      "category": "diabetes",
      "description": "Type 2",
      "duration": "oneToSixMonths",
      "severity": "mild",
      "medication": "no"
    }
  ],
  "goalWeight": 73,
  "goalWeightUnit": "kg",
  "goalTimeline": "custom",
  "goalTimelineCustomDate": "2026-12-01",
  "startWeight": 70,
  "startWeightUnit": "kg",
  "dietType": "nonVegetarian",
  "foodAllergies": ["peanuts"],
  "foodsToAvoid": "fried food",
  "mealsPerDay": 5,
  "cookingSkills": "basic",
  "medications": ["no"],
  "eatingHabits": "similar_some_variation",
  "livingArea": "south_india",
  "livingState": "tamil_nadu",
  "dietPlanInterest": "highProtein",
  "foodPreferences": ["rice_based"],
  "meatPreferences": ["chicken"]
}
```

### Field reference

| Field | Type | Required | Notes |
|---|---|---|---|
| `personalDetails.age` | int | yes* | |
| `personalDetails.gender` | string | yes* | e.g. `male` / `female` |
| `personalDetails.heightCm` | int | yes* | |
| `personalDetails.weight` | number | yes* | |
| `personalDetails.weightUnit` | string | yes* | app sends `"kg"` |
| `goal` | string | yes* | `loseWeight` \| `maintainWeight` \| `gainWeight` |
| `activityLevel` | string | yes* | `sedentary` \| `lightlyActive` \| `moderatelyActive` \| `veryActive` |
| `healthProblems` | array \| `null` | yes | `null` or `[]` means none |
| `goalWeight` | number | yes* | |
| `goalWeightUnit` | string | yes* | `"kg"` |
| `goalTimeline` | string | yes* | e.g. `custom` |
| `goalTimelineCustomDate` | string | no | `YYYY-MM-DD` when timeline is custom |
| `startWeight` | number | no | |
| `startWeightUnit` | string | no | `"kg"` |
| `dietType` | string | no | see enum below |
| `foodAllergies` | string[] | yes | may be `[]` |
| `foodsToAvoid` | string | yes | may be `""` |
| **`mealsPerDay`** | int | **yes (critical)** | **`3` \| `4` \| `5` only** |
| `cookingSkills` | string | no | `beginner` \| `basic` \| `experienced` |
| `medications` | string[] | no | |
| `eatingHabits` | string | no | e.g. `same_every_day`, `similar_some_variation`, `rotate_familiar`, `experiment` |
| `livingArea` | string | no | region e.g. `south_india`, `north_india` |
| `livingState` | string | no | state e.g. `tamil_nadu`, `punjab` |
| `dietPlanInterest` | string | no | `heartHealthy` \| `highProtein` \| `healthyNatural` |
| `foodPreferences` | string[] | no | |
| `meatPreferences` | string[] | no | |

\*If profile is incomplete mid-edit, app may send a **partial** body with only diet fields + `mealsPerDay`. Prefer handling partial updates safely.

### Enums the app sends

**`goal`**
- `loseWeight`
- `maintainWeight`
- `gainWeight`

**`activityLevel`**
- `sedentary`
- `lightlyActive`
- `moderatelyActive`
- `veryActive`

**`dietType`**
- `nonVegetarian`
- `eggetarian`
- `vegetarian`
- `vegan`
- `pescatarian`
- `flexitarian`
- `lactoVegetarian`
- `lactoOvoVegetarian`

**`dietPlanInterest`**
- `heartHealthy`
- `highProtein`
- `healthyNatural`

**`healthProblems[].category`**
- `diabetes`
- `bloodPressure`
- `respiratory`
- `digestive`
- `stress`
- `immunity`
- `highCholesterol`
- `other`

**`healthProblems[].duration`**
- `lessThanOneWeek`
- `oneToFourWeeks`
- `oneToSixMonths`
- `moreThanSixMonths`

**`healthProblems[].severity`**
- `mild` \| `moderate` \| `severe`

**`healthProblems[].medication`**
- `no` \| `yes` \| `preferNotToSay`

---

## 4. `mealsPerDay` → meal slots (MUST match)

Backend **must** generate this many meals **per day**, with these exact `mealType` labels:

| `mealsPerDay` | Slots (in order) |
|---|---|
| **3** | `Breakfast` · `Lunch` · `Dinner` |
| **4** | `Breakfast` · `Lunch` · `Snack` · `Dinner` |
| **5** | `Breakfast` · `Morning Snack` · `Lunch` · `Evening Snack` · `Dinner` |

Rules:
1. Count of meals in each day = `mealsPerDay`
2. Use the labels above (case-sensitive preferred)
3. Keep slot order chronological for the day
4. Do **not** invent other slot names for these counts

---

## 5. Response shape (POST + GET) — what mobile parses

App accepts either top-level fields or wrapped in `data` / `nutritionPlan` / `plan`.

### Preferred response

```json
{
  "data": {
    "nutritionPlan": {
      "dailyCalories": 2400,
      "proteinG": 140,
      "carbsG": 260,
      "fatG": 70,
      "bmr": 1650,
      "tdee": 2400,
      "targetWeightKg": 73,
      "goalLabel": "Gain 3 kg",
      "foodsToAvoid": ["fried food"],
      "tips": [
        "Prefer whole foods",
        "Hit protein at every meal"
      ],
      "homePreview": {
        "mealType": "Breakfast",
        "name": "Oats + Banana + Almonds",
        "calories": 420,
        "proteinG": 18,
        "timeLabel": "8:00 AM",
        "ingredients": ["Oats", "Banana", "Almonds"]
      },
      "weeklyMealPlan": {
        "weekStart": "2026-09-22",
        "dailyCalorieTarget": 2400,
        "goalLabel": "Gain 3 kg",
        "days": [
          {
            "date": "2026-09-24",
            "weekday": "Wednesday",
            "weekdayNumber": 3,
            "meals": [
              {
                "id": "2026-09-24_breakfast",
                "mealType": "Breakfast",
                "name": "Oats + Banana + Almonds",
                "timeLabel": "8:00 AM",
                "calories": 420,
                "proteinG": 18,
                "carbsG": 55,
                "fatG": 14,
                "status": "upcoming",
                "description": "Steady energy breakfast",
                "ingredients": ["Oats", "Banana", "Almonds"],
                "why": "Protein + complex carbs",
                "alternatives": [
                  {
                    "id": "2026-09-24_breakfast_alt_1",
                    "mealType": "Breakfast",
                    "name": "Egg toast + fruit",
                    "calories": 400,
                    "proteinG": 22,
                    "carbsG": 40,
                    "fatG": 16,
                    "ingredients": ["Eggs", "Bread", "Apple"],
                    "why": "Higher protein swap"
                  },
                  {
                    "id": "2026-09-24_breakfast_alt_2",
                    "mealType": "Breakfast",
                    "name": "Poha + peanuts",
                    "calories": 380,
                    "proteinG": 12,
                    "carbsG": 58,
                    "fatG": 10,
                    "ingredients": ["Poha", "Peanuts"],
                    "why": "Light regional option"
                  }
                ]
              },
              {
                "id": "2026-09-24_morning_snack",
                "mealType": "Morning Snack",
                "name": "Greek yogurt + berries",
                "timeLabel": "10:30 AM",
                "calories": 180,
                "proteinG": 15,
                "carbsG": 18,
                "fatG": 4,
                "status": "upcoming",
                "ingredients": ["Greek yogurt", "Berries"],
                "why": "Protein bridge",
                "alternatives": []
              },
              {
                "id": "2026-09-24_lunch",
                "mealType": "Lunch",
                "name": "Chicken rice bowl",
                "timeLabel": "1:00 PM",
                "calories": 650,
                "proteinG": 45,
                "carbsG": 70,
                "fatG": 18,
                "status": "upcoming",
                "ingredients": ["Chicken", "Rice", "Veggies"],
                "why": "Main protein meal",
                "alternatives": []
              },
              {
                "id": "2026-09-24_evening_snack",
                "mealType": "Evening Snack",
                "name": "Protein shake",
                "timeLabel": "5:00 PM",
                "calories": 200,
                "proteinG": 25,
                "carbsG": 10,
                "fatG": 3,
                "status": "upcoming",
                "ingredients": ["Whey", "Milk"],
                "why": "Protein fill",
                "alternatives": []
              },
              {
                "id": "2026-09-24_dinner",
                "mealType": "Dinner",
                "name": "Grilled fish + salad",
                "timeLabel": "8:00 PM",
                "calories": 550,
                "proteinG": 40,
                "carbsG": 30,
                "fatG": 22,
                "status": "upcoming",
                "ingredients": ["Fish", "Salad"],
                "why": "Light dinner",
                "alternatives": []
              }
            ]
          }
        ]
      }
    }
  }
}
```

### Response field notes

#### Plan / macros
| Field | Also accepted as | Notes |
|---|---|---|
| `dailyCalories` | `calories`, `calorieGoal`, `dailyCalorieGoal`, `recommendedCalories`, `dailyCalorieTarget` | Daily kcal target |
| `proteinG` | `protein`, `proteinGoalG` | |
| `carbsG` | `carbs`, `carbsGoalG` | |
| `fatG` | `fat`, `fatGoalG` | |
| `targetWeightKg` | `goalWeightKg`, `targetWeight` | |
| `goalLabel` | `goal` | Short UI string |
| `tips` | `aiTips`, `recommendations`, `lifestyleTips` | string[] |
| `foodsToAvoid` | `avoid`, `avoidFoods` | string[] |
| `homePreview` | `home_preview` | One meal for home card |
| `weeklyMealPlan` | `weekly_meal_plan`, `weeklyPlan`, `weekPlan`, `mealPlan` | Full week |

#### Day
| Field | Notes |
|---|---|
| `date` | `YYYY-MM-DD` preferred |
| `weekday` | e.g. `Monday` |
| `weekdayNumber` | **Mon=1 … Sun=7** (app uses this) |
| `meals` | Array of meal objects (length = `mealsPerDay`) |

#### Meal (required for weekly UI)
| Field | Required | Notes |
|---|---|---|
| `id` | **yes** | Stable unique id per slot (used for local swap tracking) |
| `mealType` | **yes** | Exact slot label from section 4 |
| `name` | **yes** | Dish name shown on card |
| `calories` | **yes** | int |
| `proteinG` | yes | also accepts `protein` |
| `carbsG` | yes | also accepts `carbs` |
| `fatG` | yes | also accepts `fat` |
| `timeLabel` | recommended | e.g. `"8:00 AM"` |
| `ingredients` | recommended | string[] |
| `description` | optional | |
| `why` | optional | reason this meal fits the plan |
| `status` | optional | `next` \| `upcoming` \| `completed` |
| **`alternatives`** | **strongly recommended** | 2–4 swap options (same `mealType`) |

#### Alternative meal object
Same shape as a meal (at least `id`, `mealType`, `name`, macros).  
Can also be sent as `swapOptions` / `swap_options`.

---

## 6. Swap / More options / Don’t suggest

### Current app behavior (no extra endpoints)

| Action | Data source |
|---|---|
| **Swap** | `meal.alternatives[]` first; if empty, other week meals with same `mealType` |
| **More options** | Broader list from same week (same type preferred) |
| **Don’t suggest** | Client hides that meal name locally and auto-picks next alternative — **not sent to backend** |

### Backend checklist for good swap UX
1. Every meal includes **2–4** `alternatives`
2. Each alternative has same `mealType` as parent
3. Alternative macros roughly fit the slot calorie budget
4. Stable unique `id`s for main meal + alternatives

### Optional future APIs (not implemented in app yet)

If you want server-persisted swap later:

```
POST /api/v1/nutrition/plan/meals/{mealId}/swap
Body: { "alternativeMealId": "..." }

GET  /api/v1/nutrition/plan/meals/{mealId}/alternatives

POST /api/v1/nutrition/plan/meals/{mealId}/dont-suggest
Body: { "reason": "...", "mealName": "..." }
```

Mobile can wire these later. **For now, embed `alternatives` in the plan response.**

---

## 7. Log planned meal — `POST /meals`

When user taps “Log” on a plan meal:

```json
{
  "name": "Oats + Banana + Almonds",
  "calories": 420,
  "protein": 18,
  "carbs": 55,
  "fat": 14,
  "mealTime": "breakfast",
  "quantity": 100,
  "unit": "g",
  "grams": 100,
  "date": "2026-09-24"
}
```

### `mealTime` mapping (diary only has 4 slots)

| Plan `mealType` | Diary `mealTime` |
|---|---|
| Breakfast | `breakfast` |
| Lunch | `lunch` |
| Dinner | `dinner` |
| Snack | `snack` |
| Morning Snack | `snack` |
| Evening Snack | `snack` |

---

## 8. Error responses

Use clear HTTP codes + message:

```json
{
  "message": "Nutrition plan could not be generated"
}
```

| Code | Meaning for app |
|---|---|
| `200` / `201` | Success |
| `404` on GET | No plan yet → app will POST create |
| `4xx` | Show `message` to user |
| `5xx` | Retry / unavailable |

---

## 9. Acceptance checklist for backend

- [ ] `POST /nutrition/plan` accepts full body including `mealsPerDay`
- [ ] `GET /nutrition/plan` returns same shape
- [ ] When `mealsPerDay = 3/4/5`, each day has exactly that many meals
- [ ] `mealType` labels match section 4 exactly
- [ ] Each meal has stable `id`, `name`, macros
- [ ] Each meal has `alternatives[]` (2–4 items) for swap
- [ ] `weekdayNumber` is Mon=1 … Sun=7
- [ ] `homePreview` present for home card
- [ ] Macros (`dailyCalories`, protein/carbs/fat) present
- [ ] Respect diet type, allergies, foods to avoid, region when generating

---

## 10. Quick summary for backend

1. **One create endpoint:** `POST /api/v1/nutrition/plan`  
2. **One fetch endpoint:** `GET /api/v1/nutrition/plan`  
3. **Read `mealsPerDay`** and return the matching slot layout  
4. **Put swap options inside each meal** as `alternatives` (no separate swap API required for v1)  
5. **Logging** uses existing `POST /api/v1/meals`

Questions? Ask mobile for sample real request payloads from debug logs.
