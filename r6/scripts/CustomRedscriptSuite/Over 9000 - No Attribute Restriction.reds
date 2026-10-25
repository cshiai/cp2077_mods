@wrapMethod(SkillCheckBase) // FOR ACTIONS
	public const func Evaluate(requester: ref<GameObject>) -> Bool {
			return true;
	}

@wrapMethod(Build_ScriptConditionType) // FOR DIALOGUES
	public const quest func Evaluate(playerObject: ref<GameObject>) -> Bool {
			return true;
	}

@wrapMethod(CaptionImageIconsLogicController) // FOR STAT COMPARING DISPLAY
	public final func SetSkillCheck(argData: ref<BuildBluelinePart>) -> Void {
		let skillIconID: TweakDBID;
			inkWidgetRef.SetVisible(this.m_LifeHolder, false);
			inkWidgetRef.SetVisible(this.m_CheckHolder, false);
			inkWidgetRef.SetVisible(this.m_PayHolder, false);
			inkWidgetRef.SetVisible(this.m_GenericHolder, false);
			inkTextRef.SetText(this.m_CheckText, "9000");
			inkWidgetRef.SetOpacity(this.m_CheckBackground, 0.50);
			inkWidgetRef.SetOpacity(this.m_CheckBackgroundFail, 0.50);
			inkWidgetRef.SetVisible(this.m_CheckBackground, true);
			inkWidgetRef.SetVisible(this.m_CheckBackgroundFail, false);
			skillIconID = argData.m_record.CaptionIcon().TexturePartID().GetID();
			if TDBID.IsValid(skillIconID) {
				this.SetTexture(this.m_CheckIcon, skillIconID);
				inkWidgetRef.SetVisible(this.m_CheckHolder, true);
			};
	}

@wrapMethod(ActionSkillCheck) // FOR STAT COMPARING DISPLAY
	public final func CreateSkillcheckInfo(requester: ref<GameObject>) -> UIInteractionSkillCheck {
		let requiredSkill: Int32;
			this.m_wasPassed = this.m_skillCheck.Evaluate(requester);
			this.m_skillcheckDescription.isValid = true;
			this.m_skillcheckDescription.skillCheck = this.m_skillCheckName;
			this.m_skillcheckDescription.skillName = this.m_localizedName;
			this.m_skillcheckDescription.requiredSkill = 9000;
			this.m_skillcheckDescription.playerSkill = 9001;
			this.m_skillcheckDescription.actionDisplayName = this.interactionChoice.caption;
			this.m_skillcheckDescription.isPassed = this.m_wasPassed;
			this.m_skillcheckDescription.ownerID = this.GetRequesterID();
			if this.m_skillCheck.GetAdditionalRequirements().HasAdditionalRequirements() {
				this.m_skillcheckDescription.hasAdditionalRequirements = true;
				this.m_skillcheckDescription.additionalReqOperator = this.m_skillCheck.GetAdditionalRequirements().GetOperator();
				this.m_skillcheckDescription.additionalRequirements = this.m_skillCheck.GetAdditionalRequirements().CreateDescription(requester, this.GetRequesterID());
			};
			return this.m_skillcheckDescription;
	}