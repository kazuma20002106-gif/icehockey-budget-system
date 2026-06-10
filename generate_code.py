import os

base_dir = "src/main/java/com/miyazaki/icehockey/budgetsystem/"
model_dir = base_dir + "model/"
mapper_dir = base_dir + "mapper/"
service_dir = base_dir + "service/"
controller_dir = base_dir + "controller/"
xml_dir = "src/main/resources/mapper/"

os.makedirs(model_dir, exist_ok=True)
os.makedirs(mapper_dir, exist_ok=True)
os.makedirs(service_dir, exist_ok=True)
os.makedirs(controller_dir, exist_ok=True)
os.makedirs(xml_dir, exist_ok=True)

models = {
    "Member": "private Integer id;\n    private String name;\n    private Integer age;\n    private String grade;\n    private String role;",
    "BudgetType": "private Integer id;\n    private String name;\n    private String description;",
    "Project": "private Integer id;\n    private String name;\n    private Integer budgetTypeId;\n    private String targetCategory;\n    private java.time.LocalDate eventDate;\n    private String locationVenue;\n    private String locationAccommodation;\n    private java.time.LocalDateTime createdAt;",
    "ProjectParticipant": "private Integer id;\n    private Integer projectId;\n    private Integer memberId;\n    private Boolean isAccommodated;\n    private Member member;",
    "Expense": "private Integer id;\n    private Integer projectParticipantId;\n    private String transportMethod;\n    private Integer transportCost;\n    private Integer accommodationCost;\n    private Integer miscellaneousCost;",
    "ProjectSummaryExpense": "private Integer id;\n    private Integer projectId;\n    private Integer rentalCost;\n    private Integer suppliesCost;\n    private Integer parkingCost;\n    private Integer compensationCost;\n    private Integer serviceCost;"
}

for name, fields in models.items():
    with open(model_dir + f"{name}.java", "w", encoding="utf-8") as f:
        f.write(f"package com.miyazaki.icehockey.budgetsystem.model;\n\npublic class {name} {{\n    {fields}\n")
        # generate getters and setters
        for line in fields.split(";"):
            line = line.strip()
            if not line: continue
            parts = line.split()
            type_name = parts[-2]
            var_name = parts[-1]
            cap_var = var_name[0].upper() + var_name[1:]
            f.write(f"\n    public {type_name} get{cap_var}() {{ return {var_name}; }}\n")
            f.write(f"    public void set{cap_var}({type_name} {var_name}) {{ this.{var_name} = {var_name}; }}\n")
        f.write("}\n")

print("Generated boilerplate files.")
