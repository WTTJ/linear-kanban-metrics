# 🤖 AI Code Review System

This repository uses GitHub Copilot to automatically review pull requests against our established coding standards and design patterns.

## 🎯 What it Reviews

The AI system performs comprehensive analysis on every pull request, checking for:

### 🏗️ Architecture & Design
- **Modular Architecture**: Adherence to our layered design with clear separation of concerns
- **Design Patterns**: Proper implementation of Strategy, Adapter, Builder, and Repository patterns
- **SOLID Principles**: Single responsibility, open/closed, dependency inversion, etc.
- **Zeitwerk Compliance**: Proper autoloading without manual require statements

### 💎 Ruby Best Practices
- **Idiomatic Ruby**: Use of modern Ruby 3.0+ features and conventions
- **Code Structure**: Method/class length, nesting levels, readability
- **Error Handling**: Proper exception handling and edge case coverage
- **Performance**: Efficient algorithms and memory usage patterns

### 🧪 Testing Quality
- **Four-Phase Pattern**: Arrange, Act, Assert, Cleanup structure
- **Test Organization**: Named subjects, single responsibility, proper grouping
- **Test Data**: FactoryBot usage, VCR for HTTP interactions
- **Coverage**: Edge cases and error conditions

### 🔒 Security & Quality
- **Security Vulnerabilities**: Beyond automated Brakeman scanning
- **Input Validation**: Proper sanitization and validation
- **API Security**: Token handling, logging practices
- **Code Smells**: God objects, primitive obsession, tight coupling

## 🚀 How it Works

1. **Trigger**: Runs automatically on every PR to `main`, `master`, or `develop`
2. **Context Gathering**: Collects project documentation, changed files, and static analysis results
3. **AI Analysis**: GitHub Copilot performs comprehensive review based on our standards
4. **Feedback**: Posts detailed review comment with specific, actionable recommendations
5. **Status Check**: Sets PR status based on findings (success/failure/pending)

## 📊 Review Output

Each AI review includes:

- **🎯 Overall Assessment**: Approve/Request Changes/Comment with reasoning
- **📊 Summary Score**: 1-10 rating with justification
- **✅ What's Good**: Positive highlights and well-implemented patterns
- **🔧 Areas for Improvement**: Specific, actionable feedback with examples
- **🚨 Critical Issues**: Security vulnerabilities, breaking changes, major violations
- **💡 Suggestions**: Optional improvements and best practices
- **🧪 Testing Notes**: Test quality and coverage observations

## 🛠️ Setup Instructions

### Prerequisites
- GitHub repository with Actions enabled
- GitHub Copilot subscription (individual or organization)
- GitHub CLI installed locally

### Quick Setup
```bash
# Run the automated setup script
./bin/setup-ai-review
```

### Manual Setup
1. **Enable GitHub Copilot**:
   - Ensure you have a GitHub Copilot subscription
   - Install the GitHub Copilot CLI: `gh extension install github/gh-copilot`

2. **Commit Workflow Files**:
   ```bash
   git add .github/
   git commit -m "feat: add AI code review with GitHub Copilot"
   git push
   ```

## 📋 Configuration Files

### Core Files
- **`.github/workflows/copilot-code-review.yml`**: Main GitHub Action workflow
- **`.github/AI_REVIEW_STANDARDS.md`**: Detailed coding standards and patterns
- **`bin/setup-ai-review`**: Automated setup script

### Standards Configuration
The AI review system enforces standards defined in `.github/AI_REVIEW_STANDARDS.md`, including:

- Module organization and Zeitwerk conventions
- Required design patterns (Strategy, Adapter, Builder, Repository)
- SOLID principles enforcement
- Ruby code style and idioms
- Testing patterns and structure
- Security requirements
- Performance considerations

## 🔧 Customization

### Adjusting Review Sensitivity
Edit the workflow's prompt in `copilot-code-review.yml` to:
- Focus on specific areas (architecture vs. style)
- Adjust strictness level
- Add project-specific requirements

### Modifying Standards
Update `.github/AI_REVIEW_STANDARDS.md` to:
- Add new coding patterns
- Modify existing requirements
- Include project-specific anti-patterns

### Review Scope
Configure which files trigger reviews by editing the workflow's file filters.

## 🧪 Testing the System

### Test the Setup
```bash
# Test API key and configuration
./bin/setup-ai-review
```

### Create Test PR
1. Create a feature branch
2. Make a small change to a Ruby file
3. Open a pull request
4. Watch the AI review action run
5. Check the review comment and status

### Example Test Change
```ruby
# Add a simple method to test the review system
def example_method
  puts "Testing AI review system"
end
```

## 📈 Monitoring and Analytics

### GitHub Actions
- View workflow runs: **Actions** tab → **AI Code Review with GitHub Copilot**
- Check run logs for detailed analysis process
- Download artifacts for review data

### Review Metrics
The system tracks:
- Review completion rate
- Common issue patterns
- Code quality trends over time
- AI confidence scores

## 🚨 Troubleshooting

### Common Issues

**GitHub Copilot Issues**
```bash
# Check if Copilot CLI is installed
gh extension list | grep copilot

# Install if missing
gh extension install github/gh-copilot

# Test access
gh copilot suggest --type shell "echo test"
```

**Workflow Not Running**
- Check PR targets correct branch (`main`, `master`, `develop`)
- Verify workflow file is in `.github/workflows/`
- Check Actions permissions in repository settings

**Review Quality Issues**
- Update `.github/AI_REVIEW_STANDARDS.md` with more specific guidance
- Adjust the prompt in the workflow file
- Provide more context in PR descriptions

### Debug Mode
Enable detailed logging by setting environment variables in the workflow:
```yaml
env:
  ZEITWERK_DEBUG: 1
  GH_DEBUG: api
```

## 🤝 Contributing

When contributing to the AI review system:

1. Test changes on a fork first
2. Update documentation for significant changes
3. Follow the same standards the AI enforces
4. Consider impact on review quality and performance

## 📚 Resources

- [GitHub Copilot Documentation](https://docs.github.com/en/copilot)
- [GitHub CLI Copilot Extension](https://github.com/github/gh-copilot)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Project Technical Documentation](./TECHNICAL_DOCUMENTATION.md)
- [Testing Guide](./TESTING_GUIDE.md)

---

**Note**: The AI reviewer is a powerful tool but doesn't replace human judgment. Use it as a first-pass filter and supplement with manual reviews for complex architectural decisions.
